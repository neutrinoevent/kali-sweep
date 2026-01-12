#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# kali_sweep_v3_2_1.sh - Hostile Housekeeping / Security Sweep for Kali
#
# Features:
#  - Safe-by-default security sweep with optional paranoid mode
#  - Structured reports: network/processes/persistence/filesystem/logs/integrity/summary/diff
#  - Network disruption (DNS flush, route cache flush, NetworkManager restart)
#  - Persistence enumeration (systemd, timers, cron, systemd user units)
#  - Suspicious process pattern triage + optional interactive kill
#  - Recent-changes hunting (system executables, recent home files, hidden dotfiles)
#  - IPv4/IPv6-aware established-connection heuristic (configurable "common ports")
#  - Integrity artifacts: critical binary hashes, report hashes, tarball + sha256
#  - Baseline / compare and diff outputs
#  - Resource usage tracking + risk scoring
#  - Optional notifications (email + webhook with retries and exponential backoff),
#    rate-limited by risk threshold
#  - Optional syslog logging with facility/priority + structured message
#  - Atomic lock to prevent concurrent runs (flock preferred; mkdir fallback)
#  - Safe config parsing (whitelist), env var overrides (KALI_SWEEP_*)
#  - Quiet mode for cron/scheduled runs
#
# Sample config file (/etc/kali-sweep.conf):
#   # Lines starting with # are ignored. Format KEY=VALUE (quotes optional)
#   SINCE_HOURS=12
#   PARANOID=1
#   PARALLEL=1
#   COMMON_PORTS="22,53,80,443,8080"
#   HIGH_RISK_THRESHOLD=50
#   NOTIFY_THRESHOLD=30
#   NOTIFY_EMAIL="alerts@example.invalid"
#   WEBHOOK_URL="https://example.com/hook"
#   WEBHOOK_RETRIES=3
#   WEBHOOK_RETRY_SLEEP=2
#   WEBHOOK_BACKOFF=2
#   WEBHOOK_MAX_SLEEP=30
#   SYSLOG=1
#   SYSLOG_TAG="kali-sweep"
#   SYSLOG_PRI="authpriv.notice"
#
# Exit codes:
#  0 = Success, low risk
#  1 = Script/runtime error
#  2 = Success, but high risk detected (>= HIGH_RISK_THRESHOLD)
#
# Changelog:
#  v3.2:
#   - Added safe config parser (no source)
#   - Added --quiet for cron
#   - Added env var overrides (KALI_SWEEP_*)
#   - Added structured syslog message with priority
#   - Added exit code standardization and documentation
#  v3.2.1:
#   - Atomic locking via flock (or mkdir fallback)
#   - Dry-run awareness for lock acquisition
#   - Config validation (ranges and integer sanity checks)
#   - Webhook exponential backoff controls
#   - JSON schema hint in webhook payload
###############################################################################

VERSION="3.2.1"

# ---------- Defaults (may be overridden by config/env/args) ----------
DRY_RUN=0
VERBOSE=0
QUIET=0
PARANOID=0
INTERACTIVE=0
PARALLEL=0

SINCE_HOURS=24
REPORT_DIR="/var/log/kali-sweep"

TIMEOUT_SHORT=20
TIMEOUT_MED=60
TIMEOUT_LONG=180

COMMON_PORTS="22,53,80,443"

BASELINE_DIR=""
COMPARE_DIR=""

UFW_DEFAULT_DENY=0

NOTIFY_EMAIL=""
WEBHOOK_URL=""
WEBHOOK_RETRIES=3
WEBHOOK_RETRY_SLEEP=2
WEBHOOK_BACKOFF=2
WEBHOOK_MAX_SLEEP=30
NOTIFY_THRESHOLD=0

SYSLOG=0
SYSLOG_TAG="kali-sweep"
SYSLOG_PRI="authpriv.notice"

HIGH_RISK_THRESHOLD=50

STAMP="$(date +'%Y%m%d_%H%M%S')"
HOST="$(hostname -s 2>/dev/null || hostname)"
SCRIPT_BASENAME="$(basename "$0")"

# ---------- Logging ----------
log() {
  if [[ "$QUIET" -eq 1 ]]; then return 0; fi
  echo "[$(date +'%F %T')] $*"
}
vlog() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    log "$@"
  fi
  return 0
}
warn() { log "WARNING: $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: sudo $SCRIPT_BASENAME [options]

Core:
  --dry-run                 Print commands but do not execute them
  --since-hours N           Look back window (default: ${SINCE_HOURS})
  --report-dir PATH         Reports root (default: ${REPORT_DIR})
  -v, --verbose             More output
  -q, --quiet               Minimal output (good for cron)
  -h, --help                Help
  --version                 Print version

Modes:
  --paranoid                Enable extra checks (SUID/SGID, dpkg verify, env-clean execution)
  --interactive             Prompt for risky actions (e.g., kill suspicious processes)
  --parallel                Run some collections concurrently (faster on multi-core)

Heuristics / performance:
  --common-ports "CSV"      Ports treated as common for established conn heuristic
                            (default: "${COMMON_PORTS}")
  --timeout-short N         Seconds (default: ${TIMEOUT_SHORT})
  --timeout-med N           Seconds (default: ${TIMEOUT_MED})
  --timeout-long N          Seconds (default: ${TIMEOUT_LONG})

Baseline / compare:
  --baseline DIR            Save a baseline snapshot into DIR
  --compare DIR             Compare current run against baseline DIR
  --baseline-and-compare DIR Create/update baseline DIR AND run compare against it

Optional:
  --ufw-default-deny        (PARANOID) Apply UFW default deny (best-effort)
  --config FILE             Load settings from config file (safe whitelist parsing)
  --notify-email ADDR       Send summary via mail/mailx (if available)
  --webhook URL             POST JSON summary to webhook (if curl available)
  --notify-threshold N      Only notify if risk score >= N (default: ${NOTIFY_THRESHOLD})
  --high-risk-threshold N   Exit 2 if risk score >= N (default: ${HIGH_RISK_THRESHOLD})
  --syslog                  Send a structured line to syslog (logger)
  --syslog-tag TAG          Syslog tag (default: ${SYSLOG_TAG})
  --syslog-pri PRI          Syslog priority (default: ${SYSLOG_PRI})

Environment variable overrides (examples):
  KALI_SWEEP_PARANOID=1
  KALI_SWEEP_SINCE_HOURS=6
  KALI_SWEEP_COMMON_PORTS="22,53,80,443,8080"
  KALI_SWEEP_NOTIFY_EMAIL="you@domain"
  KALI_SWEEP_WEBHOOK_URL="https://example.com/hook"
  KALI_SWEEP_WEBHOOK_RETRIES=5
  KALI_SWEEP_WEBHOOK_BACKOFF=2
  KALI_SWEEP_SYSLOG=1

Exit codes:
  0  success, low risk
  1  script/runtime error
  2  success, high risk detected (>= high-risk-threshold)

Examples:
  sudo $SCRIPT_BASENAME --since-hours 12 --parallel
  sudo $SCRIPT_BASENAME --paranoid --since-hours 6 --parallel
  sudo $SCRIPT_BASENAME --baseline /root/kali-baseline
  sudo $SCRIPT_BASENAME --compare /root/kali-baseline
  sudo $SCRIPT_BASENAME --config /etc/kali-sweep.conf --quiet --parallel
EOF
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run as root (use sudo)."
  fi
}

have_timeout() { command -v timeout >/dev/null 2>&1; }

twrap() {
  local seconds="$1"
  local cmd="$2"
  if have_timeout; then
    echo "timeout ${seconds} bash -lc \"set -o pipefail; ${cmd}\""
  else
    echo "bash -lc \"set -o pipefail; ${cmd}\""
  fi
}

run() {
  local cmd="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    [[ "$QUIET" -eq 0 ]] && echo "[DRY] $cmd"
    return 0
  fi

  if [[ "$PARANOID" -eq 1 ]]; then
    env -i PATH="/usr/sbin:/usr/bin:/sbin:/bin" /bin/bash -lc "set -o pipefail; $cmd"
  else
    /bin/bash -lc "set -o pipefail; $cmd"
  fi
}

run_out() {
  local cmd="$1"
  local outfile="$2"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    [[ "$QUIET" -eq 0 ]] && echo "[DRY] $cmd"
    mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
    printf "DRY_RUN=1 (no command executed)\nCMD=%s\n" "$cmd" > "$outfile" || true
    return 0
  fi

  if ! run "$cmd"; then
    warn "command failed: $cmd"
    return 1
  fi
  if [[ ! -s "$outfile" ]]; then
    warn "expected output missing/empty: $outfile"
    return 1
  fi
  return 0
}

mkdirp_secure() {
  local dir="$1"
  mkdir -p "$dir"
  chmod 0700 "$dir" 2>/dev/null || true
}

csv_to_egrep() {
  local csv="$1"
  local re
  re="$(echo "$csv" | tr -d ' ' | tr ',' '|' )"
  echo "^(${re})$"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  echo "$s"
}

strip_quotes() {
  local s="$1"
  s="$(trim "$s")"
  if [[ "$s" =~ ^\".*\"$ ]]; then s="${s:1:${#s}-2}"; fi
  if [[ "$s" =~ ^\'.*\'$ ]]; then s="${s:1:${#s}-2}"; fi
  echo "$s"
}

parse_bool() {
  local v
  v="$(echo "$(strip_quotes "$1")" | tr '[:upper:]' '[:lower:]')"
  case "$v" in
    1|true|yes|on) echo 1 ;;
    0|false|no|off|"") echo 0 ;;
    *) echo 0 ;;
  esac
}

apply_kv() {
  local key="$1"
  local val="$2"
  key="$(trim "$key")"
  val="$(strip_quotes "$val")"

  case "$key" in
    SINCE_HOURS) SINCE_HOURS="$val" ;;
    REPORT_DIR) REPORT_DIR="$val" ;;
    PARANOID) PARANOID="$(parse_bool "$val")" ;;
    PARALLEL) PARALLEL="$(parse_bool "$val")" ;;
    INTERACTIVE) INTERACTIVE="$(parse_bool "$val")" ;;
    VERBOSE) VERBOSE="$(parse_bool "$val")" ;;
    QUIET) QUIET="$(parse_bool "$val")" ;;
    COMMON_PORTS) COMMON_PORTS="$val" ;;
    TIMEOUT_SHORT) TIMEOUT_SHORT="$val" ;;
    TIMEOUT_MED) TIMEOUT_MED="$val" ;;
    TIMEOUT_LONG) TIMEOUT_LONG="$val" ;;
    BASELINE_DIR) BASELINE_DIR="$val" ;;
    COMPARE_DIR) COMPARE_DIR="$val" ;;
    UFW_DEFAULT_DENY) UFW_DEFAULT_DENY="$(parse_bool "$val")" ;;
    NOTIFY_EMAIL) NOTIFY_EMAIL="$val" ;;
    WEBHOOK_URL) WEBHOOK_URL="$val" ;;
    WEBHOOK_RETRIES) WEBHOOK_RETRIES="$val" ;;
    WEBHOOK_RETRY_SLEEP) WEBHOOK_RETRY_SLEEP="$val" ;;
    WEBHOOK_BACKOFF) WEBHOOK_BACKOFF="$val" ;;
    WEBHOOK_MAX_SLEEP) WEBHOOK_MAX_SLEEP="$val" ;;
    NOTIFY_THRESHOLD) NOTIFY_THRESHOLD="$val" ;;
    SYSLOG) SYSLOG="$(parse_bool "$val")" ;;
    SYSLOG_TAG) SYSLOG_TAG="$val" ;;
    SYSLOG_PRI) SYSLOG_PRI="$val" ;;
    HIGH_RISK_THRESHOLD) HIGH_RISK_THRESHOLD="$val" ;;
    *)
      warn "Ignoring unknown config key: $key"
      ;;
  esac
}

load_config_file() {
  local file="$1"
  [[ -f "$file" ]] || die "Config file not found: $file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    if [[ "$line" != *"="* ]]; then
      warn "Ignoring invalid config line: $line"
      continue
    fi

    local key="${line%%=*}"
    local val="${line#*=}"
    apply_kv "$key" "$val"
  done < "$file"
}

apply_env_overrides() {
  [[ -n "${KALI_SWEEP_SINCE_HOURS:-}" ]] && SINCE_HOURS="${KALI_SWEEP_SINCE_HOURS}"
  [[ -n "${KALI_SWEEP_REPORT_DIR:-}" ]] && REPORT_DIR="${KALI_SWEEP_REPORT_DIR}"
  [[ -n "${KALI_SWEEP_PARANOID:-}" ]] && PARANOID="$(parse_bool "${KALI_SWEEP_PARANOID}")"
  [[ -n "${KALI_SWEEP_PARALLEL:-}" ]] && PARALLEL="$(parse_bool "${KALI_SWEEP_PARALLEL}")"
  [[ -n "${KALI_SWEEP_INTERACTIVE:-}" ]] && INTERACTIVE="$(parse_bool "${KALI_SWEEP_INTERACTIVE}")"
  [[ -n "${KALI_SWEEP_VERBOSE:-}" ]] && VERBOSE="$(parse_bool "${KALI_SWEEP_VERBOSE}")"
  [[ -n "${KALI_SWEEP_QUIET:-}" ]] && QUIET="$(parse_bool "${KALI_SWEEP_QUIET}")"
  [[ -n "${KALI_SWEEP_COMMON_PORTS:-}" ]] && COMMON_PORTS="${KALI_SWEEP_COMMON_PORTS}"

  [[ -n "${KALI_SWEEP_NOTIFY_EMAIL:-}" ]] && NOTIFY_EMAIL="${KALI_SWEEP_NOTIFY_EMAIL}"
  [[ -n "${KALI_SWEEP_WEBHOOK_URL:-}" ]] && WEBHOOK_URL="${KALI_SWEEP_WEBHOOK_URL}"
  [[ -n "${KALI_SWEEP_WEBHOOK_RETRIES:-}" ]] && WEBHOOK_RETRIES="${KALI_SWEEP_WEBHOOK_RETRIES}"
  [[ -n "${KALI_SWEEP_WEBHOOK_RETRY_SLEEP:-}" ]] && WEBHOOK_RETRY_SLEEP="${KALI_SWEEP_WEBHOOK_RETRY_SLEEP}"
  [[ -n "${KALI_SWEEP_WEBHOOK_BACKOFF:-}" ]] && WEBHOOK_BACKOFF="${KALI_SWEEP_WEBHOOK_BACKOFF}"
  [[ -n "${KALI_SWEEP_WEBHOOK_MAX_SLEEP:-}" ]] && WEBHOOK_MAX_SLEEP="${KALI_SWEEP_WEBHOOK_MAX_SLEEP}"
  [[ -n "${KALI_SWEEP_NOTIFY_THRESHOLD:-}" ]] && NOTIFY_THRESHOLD="${KALI_SWEEP_NOTIFY_THRESHOLD}"

  [[ -n "${KALI_SWEEP_SYSLOG:-}" ]] && SYSLOG="$(parse_bool "${KALI_SWEEP_SYSLOG}")"
  [[ -n "${KALI_SWEEP_SYSLOG_TAG:-}" ]] && SYSLOG_TAG="${KALI_SWEEP_SYSLOG_TAG}"
  [[ -n "${KALI_SWEEP_SYSLOG_PRI:-}" ]] && SYSLOG_PRI="${KALI_SWEEP_SYSLOG_PRI}"

  [[ -n "${KALI_SWEEP_HIGH_RISK_THRESHOLD:-}" ]] && HIGH_RISK_THRESHOLD="${KALI_SWEEP_HIGH_RISK_THRESHOLD}" || true
}

# ---------- Arg parsing ----------
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --since-hours) SINCE_HOURS="${2:?}"; shift 2 ;;
    --report-dir) REPORT_DIR="${2:?}"; shift 2 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -q|--quiet) QUIET=1; shift ;;
    --paranoid) PARANOID=1; shift ;;
    --interactive) INTERACTIVE=1; shift ;;
    --parallel) PARALLEL=1; shift ;;
    --ufw-default-deny) UFW_DEFAULT_DENY=1; shift ;;
    --common-ports) COMMON_PORTS="${2:?}"; shift 2 ;;
    --timeout-short) TIMEOUT_SHORT="${2:?}"; shift 2 ;;
    --timeout-med) TIMEOUT_MED="${2:?}"; shift 2 ;;
    --timeout-long) TIMEOUT_LONG="${2:?}"; shift 2 ;;
    --baseline) BASELINE_DIR="${2:?}"; shift 2 ;;
    --compare) COMPARE_DIR="${2:?}"; shift 2 ;;
    --baseline-and-compare) BASELINE_DIR="${2:?}"; COMPARE_DIR="${2:?}"; shift 2 ;;
    --notify-email) NOTIFY_EMAIL="${2:?}"; shift 2 ;;
    --webhook) WEBHOOK_URL="${2:?}"; shift 2 ;;
    --notify-threshold) NOTIFY_THRESHOLD="${2:?}"; shift 2 ;;
    --high-risk-threshold) HIGH_RISK_THRESHOLD="${2:?}"; shift 2 ;;
    --syslog) SYSLOG=1; shift ;;
    --syslog-tag) SYSLOG_TAG="${2:?}"; shift 2 ;;
    --syslog-pri) SYSLOG_PRI="${2:?}"; shift 2 ;;
    --config) CONFIG_FILE="${2:?}"; shift 2 ;;
    --version) echo "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown arg: $1" ;;
  esac
done

need_root

# Apply config (if any), then env overrides (env wins over config), then args already applied.
if [[ -n "$CONFIG_FILE" ]]; then
  load_config_file "$CONFIG_FILE"
fi
apply_env_overrides

# ---------- Config validation ----------
is_int() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

if is_int "$SINCE_HOURS"; then
  if [[ "$SINCE_HOURS" -lt 1 || "$SINCE_HOURS" -gt 720 ]]; then
    warn "SINCE_HOURS=$SINCE_HOURS outside recommended range (1-720). Using 24."
    SINCE_HOURS=24
  fi
else
  warn "SINCE_HOURS=$SINCE_HOURS is not an integer. Using 24."
  SINCE_HOURS=24
fi

for v in TIMEOUT_SHORT TIMEOUT_MED TIMEOUT_LONG NOTIFY_THRESHOLD HIGH_RISK_THRESHOLD WEBHOOK_RETRIES WEBHOOK_RETRY_SLEEP WEBHOOK_BACKOFF WEBHOOK_MAX_SLEEP; do
  val="${!v:-}"
  if [[ -n "$val" ]]; then
    if ! is_int "$val"; then
      warn "$v=$val is not an integer; resetting to default."
      case "$v" in
        TIMEOUT_SHORT) TIMEOUT_SHORT=20 ;;
        TIMEOUT_MED) TIMEOUT_MED=60 ;;
        TIMEOUT_LONG) TIMEOUT_LONG=180 ;;
        NOTIFY_THRESHOLD) NOTIFY_THRESHOLD=0 ;;
        HIGH_RISK_THRESHOLD) HIGH_RISK_THRESHOLD=50 ;;
        WEBHOOK_RETRIES) WEBHOOK_RETRIES=3 ;;
        WEBHOOK_RETRY_SLEEP) WEBHOOK_RETRY_SLEEP=2 ;;
        WEBHOOK_BACKOFF) WEBHOOK_BACKOFF=2 ;;
        WEBHOOK_MAX_SLEEP) WEBHOOK_MAX_SLEEP=30 ;;
      esac
    fi
  fi
done

# ---------- Lock (atomic) ----------
LOCK_DIR="/var/lock"
LOCK_FILE="$LOCK_DIR/kali_sweep.lock"
mkdir -p "$LOCK_DIR" 2>/dev/null || true

if [[ "$DRY_RUN" -eq 1 ]]; then
  vlog "[DRY] Would acquire lock: $LOCK_FILE"
else
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  holder="$(cat "$LOCK_FILE" 2>/dev/null || true)"
  die "Another instance is running (lock busy: $LOCK_FILE). Holder PID: ${holder:-unknown}"
fi
    echo $$ 1>&9
    # lock released automatically when FD 9 closes on exit
  else
    LOCK_MKDIR="$LOCK_DIR/kali-sweep.lockdir"
    if ! mkdir "$LOCK_MKDIR" 2>/dev/null; then
      die "Another instance is running (lockdir exists: $LOCK_MKDIR)."
    fi
    echo $$ > "$LOCK_MKDIR/pid"
    trap 'rm -f "$LOCK_MKDIR/pid"; rmdir "$LOCK_MKDIR" 2>/dev/null || true' EXIT
  fi
fi

START_EPOCH="$(date +%s)"
START_MEM_MB="$(free -m 2>/dev/null | awk '/^Mem:/{print $3}' || echo 0)"

mkdirp_secure "$REPORT_DIR"

OUT="$REPORT_DIR/${HOST}_${STAMP}"
mkdirp_secure "$OUT"

NET="$OUT/network"
PROC="$OUT/processes"
PERS="$OUT/persistence"
FSYS="$OUT/filesystem"
LOGS="$OUT/logs"
INTEG="$OUT/integrity"
SUM="$OUT/summary"
DIFF="$OUT/diff"

mkdirp_secure "$NET"; mkdirp_secure "$PROC"; mkdirp_secure "$PERS"; mkdirp_secure "$FSYS"
mkdirp_secure "$LOGS"; mkdirp_secure "$INTEG"; mkdirp_secure "$SUM"; mkdirp_secure "$DIFF"

ulimit -n 4096 2>/dev/null || true

COMMON_PORTS_RE="$(csv_to_egrep "$COMMON_PORTS")"

log "Kali sweep v${VERSION} starting. Report: $OUT"
log "NOTE: Reports are root-only (0700). Use sudo to view: sudo ls -lah '$OUT' ; sudo cat '$SUM/summary.txt'"
log "since-hours=$SINCE_HOURS paranoid=$PARANOID interactive=$INTERACTIVE parallel=$PARALLEL"
log "common-ports=$COMMON_PORTS notify-threshold=$NOTIFY_THRESHOLD high-risk-threshold=$HIGH_RISK_THRESHOLD"

###############################################################################
# 1) Context snapshot
###############################################################################
log "Collecting basic context..."
run_out "uname -a > '$SUM/uname.txt'" "$SUM/uname.txt"
run_out "uptime > '$SUM/uptime.txt'" "$SUM/uptime.txt"

if [[ "$PARALLEL" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
  ( run "who > '$SUM/who.txt' || true" ) &
  ( run "last -n 50 > '$SUM/last_50.txt' || true" ) &
  ( run "ip a > '$NET/ip_a.txt' || true" ) &
  ( run "ip r > '$NET/ip_r.txt' || true" ) &
  ( run "ss -tulpn > '$NET/ss_listeners.txt' || true" ) &
  ( run "ps auxwwf > '$PROC/ps_tree.txt'" ) &
  wait
else
  run "who > '$SUM/who.txt' || true"
  run "last -n 50 > '$SUM/last_50.txt' || true"
  run "ip a > '$NET/ip_a.txt' || true"
  run "ip r > '$NET/ip_r.txt' || true"
  run "ss -tulpn > '$NET/ss_listeners.txt' || true"
  run "ps auxwwf > '$PROC/ps_tree.txt'"
fi

###############################################################################
# 2) Network disruption
###############################################################################
log "Network disruption sweep..."
if command -v resolvectl >/dev/null 2>&1; then run "resolvectl flush-caches || true"; fi
run "ip route flush cache || true"

if systemctl is-active --quiet NetworkManager 2>/dev/null; then
  run "systemctl restart NetworkManager"
else
  vlog "NetworkManager not active; skipping restart."
fi

for IFACE in tun0 wg0; do
  if ip link show "$IFACE" >/dev/null 2>&1; then
    log "Bouncing interface: $IFACE"
    run "ip link set '$IFACE' down || true"
    run "sleep 2"
    run "ip link set '$IFACE' up || true"
  fi
done

###############################################################################
# 3) Persistence enumeration
###############################################################################
log "Enumerating persistence vectors..."
run "systemctl list-unit-files --state=enabled > '$PERS/systemd_enabled_units.txt' || true"
run "systemctl list-timers --all > '$PERS/systemd_timers.txt' || true"
run "ls -la /etc/cron.* /var/spool/cron /var/spool/cron/crontabs > '$PERS/cron_ls.txt' 2>&1 || true"
run "crontab -l > '$PERS/user_crontab.txt' 2>&1 || true"
run "crontab -u root -l > '$PERS/root_crontab.txt' 2>&1 || true"

run "find /home -maxdepth 4 -type f \\( -path '*/.config/systemd/user/*.service' -o -path '*/.config/systemd/user/*.timer' \\) \
  -printf '%TY-%Tm-%Td %TT %u:%g %m %p\n' 2>/dev/null | sort -r > '$PERS/systemd_user_units.txt' || true"

###############################################################################
# 4) Suspicious process patterns
###############################################################################
log "Identifying suspicious process patterns..."
run "ps auxww > '$PROC/ps_aux_full.txt' || true"

run "grep -E '(\\bnc\\b|\\bsocat\\b|mkfifo|bash -i|sh -i|python -c|perl -e|ruby -e|php -r|curl .*\\|\\s*(sh|bash)|wget .*\\|\\s*(sh|bash))' '$PROC/ps_aux_full.txt' \
  | grep -vE '(\\bgrep\\b|${SCRIPT_BASENAME}|^USER\\b|sshd:|\\bcron\\b)' \
  > '$PROC/suspicious_process_patterns.txt' || true"

if [[ "$INTERACTIVE" -eq 1 && "$DRY_RUN" -eq 0 && -s "$PROC/suspicious_process_patterns.txt" ]]; then
  log "Interactive review: suspicious process matches found:"
  cat "$PROC/suspicious_process_patterns.txt"
  echo
  echo "Enter PID(s) to kill (space-separated), or press Enter to skip:"
  read -r PIDS || true
  if [[ -n "${PIDS:-}" ]]; then
    for pid in $PIDS; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      log "Killing PID $pid (SIGKILL)..."
      kill -9 "$pid" 2>/dev/null || warn "failed to kill $pid"
    done
  fi
fi

###############################################################################
# 5) Persistence indicators
###############################################################################
log "Checking for common persistence indicators..."
run "find /home -name authorized_keys -type f -exec ls -la {} + 2>/dev/null > '$PERS/authorized_keys_locations.txt' || true"

run "(
  echo '### /etc/ld.so.preload (if present)'; ls -la /etc/ld.so.preload 2>/dev/null || true; echo;
  echo '### Contents (/etc/ld.so.preload)'; cat /etc/ld.so.preload 2>/dev/null || true; echo;
  echo '### Grep LD_PRELOAD references';
  grep -R --binary-files=text --line-number 'LD_PRELOAD' \
    /etc/environment /etc/profile /etc/profile.d /etc/bash.bashrc /etc/zsh/zshrc /etc/zsh/zprofile /etc/ld.so.conf.d 2>/dev/null || true
) > '$PERS/ld_preload_audit.txt' || true"

run "(
  echo '### Suspicious lines in shell rc files (home)';
  find /home -maxdepth 3 -type f \\( -name '.bashrc' -o -name '.zshrc' -o -name '.profile' -o -name '.zprofile' -o -name '.bash_profile' \\) -print 2>/dev/null |
  while read -r f; do
    echo; echo \"## \$f\";
    grep --binary-files=text -nE '(LD_PRELOAD|curl|wget|nc\\b|socat\\b|mkfifo|base64|openssl enc|python -c|perl -e|nohup|setsid|/dev/tcp|systemctl --user|crontab|@reboot)' \"\$f\" 2>/dev/null || true
  done
) > '$PERS/shell_rc_suspicious_lines.txt' || true"

###############################################################################
# 6) Filesystem changes
###############################################################################
log "Hunting for recently modified executables (last ${SINCE_HOURS}h)..."
run "$(twrap "$TIMEOUT_MED" "find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt \
  -type f -executable -mmin -$((SINCE_HOURS*60)) \
  -printf '%TY-%Tm-%Td %TT %u:%g %m %p\n' 2>/dev/null | sort -r > '$FSYS/recent_exec_system.txt'") || true"

log "Hunting for recently modified files in /home (last ${SINCE_HOURS}h)..."
run "$(twrap "$TIMEOUT_LONG" "find /home -maxdepth 6 -type f -mmin -$((SINCE_HOURS*60)) \
  -printf '%TY-%Tm-%Td %TT %u:%g %m %p\n' 2>/dev/null | sort -r | head -n 3000 > '$FSYS/recent_home_files_top3000.txt'") || true"

log "Capturing hidden files (top) in /home..."
run "$(twrap "$TIMEOUT_LONG" "find /home -maxdepth 4 -type f -name '.*' \
  -printf '%TY-%Tm-%Td %TT %u:%g %m %p\n' 2>/dev/null | sort -r | head -n 3000 > '$FSYS/hidden_files_top3000.txt'") || true"

###############################################################################
# 7) Network connections + IPv6-safe port extraction
###############################################################################
log "Capturing sockets & connections..."
run "ss -tpna > '$NET/ss_tcp_all.txt' || true"
run "ss -uapn > '$NET/ss_udp_all.txt' || true"

run "(
  echo '### Established TCP connections (heuristic: non-local, remote port NOT in common list)';
  ss -tnp state established 2>/dev/null | awk -v re=\"$COMMON_PORTS_RE\" '
    function extract_port(addr,   tmp) {
      if (addr ~ /\\]:[0-9]+$/) { tmp=addr; sub(/.*\\]:/, \"\", tmp); return tmp }
      if (addr ~ /:[0-9]+$/) { tmp=addr; sub(/.*:/, \"\", tmp); return tmp }
      return \"\"
    }
    NR==1 {print; next}
    {
      r=\$5;
      if (r ~ /(127\\.0\\.0\\.1|\\[::1\\]|localhost)/) next;
      rp=extract_port(r);
      if (rp != \"\" && rp !~ re) print
    }'
) > '$NET/established_uncommon_ports.txt' || true"

###############################################################################
# 8) Logs
###############################################################################
log "Collecting journal warnings/errors..."
if command -v journalctl >/dev/null 2>&1; then
  run "journalctl -p warning..alert --since '${SINCE_HOURS} hour ago' > '$LOGS/journal_warn_last_${SINCE_HOURS}h.txt' 2>&1 || true"
  run "journalctl --since '${SINCE_HOURS} hour ago' | tail -n 4000 > '$LOGS/journal_tail_4000.txt' 2>&1 || true"
fi

###############################################################################
# 9) Integrity + paranoid extras
###############################################################################
log "Hashing critical binaries..."
run "(
  echo '### sha256 critical binaries';
  for bin in /bin/bash /bin/sh /usr/bin/sudo /usr/sbin/sshd /usr/bin/ssh /usr/bin/curl /usr/bin/wget; do
    [[ -f \"\$bin\" ]] && sha256sum \"\$bin\"
  done
) > '$INTEG/critical_bin_hashes.txt' || true"

if [[ "$PARANOID" -eq 1 ]]; then
  log "PARANOID: SUID/SGID audit..."
  run "$(twrap "$TIMEOUT_LONG" "find / -xdev \\( -perm -4000 -o -perm -2000 \\) -type f \
    -printf '%TY-%Tm-%Td %TT %m %u:%g %p\n' 2>/dev/null | sort -r > '$FSYS/suid_sgid_all.txt'") || true"

  log "PARANOID: dpkg --verify..."
  if command -v dpkg >/dev/null 2>&1; then
    run "$(twrap "$TIMEOUT_LONG" "dpkg --verify > '$INTEG/dpkg_verify.txt' 2>&1") || true"
  fi
fi

###############################################################################
# 10) Unified timeline
###############################################################################
log "Creating unified timeline..."
run "(
  cat '$FSYS/recent_exec_system.txt' 2>/dev/null || true
  cat '$FSYS/recent_home_files_top3000.txt' 2>/dev/null || true
  cat '$FSYS/suid_sgid_all.txt' 2>/dev/null || true
) | sed '/^$/d' | sort -r | head -n 1000 > '$SUM/unified_timeline_top1000.txt' || true"

###############################################################################
# 11) Light hardening
###############################################################################
log "Applying light hardening..."
run "find /home -maxdepth 2 -type d \\( -name '.config' -o -name '.local' -o -name '.ssh' \\) -exec chmod -R go-rwx {} + 2>/dev/null || true"

log "Dropping caches..."
run "sync"
run "sysctl -w vm.drop_caches=3 > '$SUM/drop_caches.txt' 2>&1 || true"
run "systemctl daemon-reload || true"

if [[ "$PARANOID" -eq 1 && "$UFW_DEFAULT_DENY" -eq 1 ]]; then
  log "PARANOID: Applying UFW default deny policy..."
  if command -v ufw >/dev/null 2>&1; then
    run "ufw --force enable || true"
    run "ufw default deny incoming || true"
    run "ufw default deny outgoing || true"
    run "ufw allow out 53 || true"
    run "ufw allow out 80 || true"
    run "ufw allow out 443 || true"
    run "ufw allow out 22 || true"
    run "ufw status verbose > '$NET/ufw_status.txt' 2>&1 || true"
  else
    warn "ufw not found; skipping."
  fi
fi

###############################################################################
# 12) Report integrity + tarball
###############################################################################
log "Creating report integrity checks..."
run "(
  cd '$OUT'
  find . -type f -maxdepth 3 -print0 2>/dev/null | xargs -0 sha256sum
) > '$INTEG/report_hashes.txt' || true"

TAR_OK=1
if [[ "$DRY_RUN" -eq 1 ]]; then
  [[ "$QUIET" -eq 0 ]] && echo "[DRY] tar czf '$OUT.tar.gz' -C '$REPORT_DIR' '${HOST}_${STAMP}'"
else
  if ! tar czf "$OUT.tar.gz" -C "$REPORT_DIR" "${HOST}_${STAMP}" 2>/dev/null; then
    TAR_OK=0
    warn "tarball creation failed."
  else
    sha256sum "$OUT.tar.gz" > "$OUT.tar.gz.sha256" 2>/dev/null || true
  fi
fi

###############################################################################
# 13) Baseline/Compare (safe dynamic list)
###############################################################################
BASELINE_COPY_LIST=()
add_to_baseline() { 
  [[ -s "$1" ]] && BASELINE_COPY_LIST+=("$1")
  return 0
}
add_to_baseline "$PERS/systemd_enabled_units.txt"
add_to_baseline "$PERS/systemd_timers.txt"
add_to_baseline "$PERS/cron_ls.txt"
add_to_baseline "$PERS/systemd_user_units.txt"
add_to_baseline "$PERS/ld_preload_audit.txt"
add_to_baseline "$INTEG/critical_bin_hashes.txt"
[[ "$PARANOID" -eq 1 ]] && add_to_baseline "$FSYS/suid_sgid_all.txt"
[[ "$PARANOID" -eq 1 ]] && add_to_baseline "$INTEG/dpkg_verify.txt"

if [[ -n "$BASELINE_DIR" ]]; then
  log "Saving baseline to: $BASELINE_DIR"
  mkdir -p "$BASELINE_DIR"
  chmod 0700 "$BASELINE_DIR" 2>/dev/null || true

  for f in "${BASELINE_COPY_LIST[@]}"; do
    cp -a "$f" "$BASELINE_DIR/$(basename "$f")" 2>/dev/null || true
  done
  cp -a "$SUM/uname.txt" "$BASELINE_DIR/uname.txt" 2>/dev/null || true
  cp -a "$SUM/uptime.txt" "$BASELINE_DIR/uptime.txt" 2>/dev/null || true
fi

if [[ -n "$COMPARE_DIR" ]]; then
  log "Comparing against baseline: $COMPARE_DIR"
  if [[ ! -d "$COMPARE_DIR" ]]; then
    warn "compare dir does not exist: $COMPARE_DIR"
  else
    for f in "${BASELINE_COPY_LIST[@]}"; do
      base="$COMPARE_DIR/$(basename "$f")"
      cur="$f"
      out="$DIFF/$(basename "$f").diff.txt"
      if [[ -f "$base" && -f "$cur" ]]; then
        diff -u "$base" "$cur" > "$out" || true
      fi
    done
  fi
fi

###############################################################################
# 14) Summary + risk score + notifications + syslog + exit code
###############################################################################
END_EPOCH="$(date +%s)"
END_MEM_MB="$(free -m 2>/dev/null | awk '/^Mem:/{print $3}' || echo 0)"
RUNTIME_S="$((END_EPOCH - START_EPOCH))"
MEM_DELTA_MB="$((END_MEM_MB - START_MEM_MB))"

SUS_PROC_COUNT="$(wc -l < "$PROC/suspicious_process_patterns.txt" 2>/dev/null || echo 0)"
RECENT_EXEC_COUNT="$(wc -l < "$FSYS/recent_exec_system.txt" 2>/dev/null || echo 0)"
RECENT_HOME_COUNT="$(wc -l < "$FSYS/recent_home_files_top3000.txt" 2>/dev/null || echo 0)"
UNCOMMON_EST_COUNT="$(wc -l < "$NET/established_uncommon_ports.txt" 2>/dev/null || echo 0)"
DIFF_NONEMPTY_COUNT="$(find "$DIFF" -type f -size +0c 2>/dev/null | wc -l || echo 0)"

RISK_SCORE=0
[[ "$SUS_PROC_COUNT" -gt 0 ]] && RISK_SCORE=$((RISK_SCORE + 25))
[[ "$UNCOMMON_EST_COUNT" -gt 1 ]] && RISK_SCORE=$((RISK_SCORE + 10))
[[ "$RECENT_EXEC_COUNT" -gt 0 ]] && RISK_SCORE=$((RISK_SCORE + 20))
[[ "$DIFF_NONEMPTY_COUNT" -gt 0 ]] && RISK_SCORE=$((RISK_SCORE + 15))
[[ "$PARANOID" -eq 1 && -s "$INTEG/dpkg_verify.txt" ]] && RISK_SCORE=$((RISK_SCORE + 10))
[[ "$RISK_SCORE" -gt 100 ]] && RISK_SCORE=100

# Create summary.txt with command grouping (safe with set -e)
{
  echo "### SUMMARY"
  echo "Version: $VERSION"
  echo "Report: $OUT"
  echo "Since-hours: $SINCE_HOURS"
  echo "Runtime: ${RUNTIME_S}s"
  echo "Memory delta: ${MEM_DELTA_MB}MB"
  echo ""
  echo "Suspicious process matches: $SUS_PROC_COUNT"
  echo "Recent system executables: $RECENT_EXEC_COUNT"
  echo "Recent home files (top): $RECENT_HOME_COUNT"
  echo "Established uncommon ports (lines): $UNCOMMON_EST_COUNT"
  echo "Diff files non-empty: $DIFF_NONEMPTY_COUNT"
  echo ""
  echo "Risk Score: $RISK_SCORE/100"
  if [[ $TAR_OK -eq 1 ]]; then
    echo "Tarball: OK"
  else
    echo "Tarball: FAILED"
  fi
} > "$SUM/summary.txt"

# JSON summary (with schema hint)
cat > "$SUM/summary.json" <<JSON
{
  "\$schema": "kali-sweep://${VERSION}/summary.schema.json",
  "version": "${VERSION}",
  "host": "${HOST}",
  "timestamp": "${STAMP}",
  "report_path": "${OUT}",
  "since_hours": ${SINCE_HOURS},
  "paranoid": ${PARANOID},
  "parallel": ${PARALLEL},
  "runtime_seconds": ${RUNTIME_S},
  "memory_delta_mb": ${MEM_DELTA_MB},
  "common_ports": "${COMMON_PORTS}",
  "counts": {
    "suspicious_process_matches": ${SUS_PROC_COUNT},
    "recent_system_executables": ${RECENT_EXEC_COUNT},
    "recent_home_files_top": ${RECENT_HOME_COUNT},
    "established_uncommon_ports_lines": ${UNCOMMON_EST_COUNT},
    "diff_nonempty_files": ${DIFF_NONEMPTY_COUNT}
  },
  "risk_score": ${RISK_SCORE},
  "tarball_ok": ${TAR_OK}
}
JSON

# Syslog
if [[ "$SYSLOG" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v logger >/dev/null 2>&1; then
  logger -t "$SYSLOG_TAG" -p "$SYSLOG_PRI" \
    "version=$VERSION host=$HOST stamp=$STAMP risk=$RISK_SCORE/100 suspicious=$SUS_PROC_COUNT uncommon_est=$UNCOMMON_EST_COUNT recent_exec=$RECENT_EXEC_COUNT diffs=$DIFF_NONEMPTY_COUNT runtime_s=$RUNTIME_S tar_ok=$TAR_OK report=$OUT"
fi

# Notifications (rate-limited)
if [[ "$RISK_SCORE" -ge "$NOTIFY_THRESHOLD" ]]; then
  # Email
  if [[ -n "$NOTIFY_EMAIL" ]]; then
    if command -v mail >/dev/null 2>&1; then
      mail -s "Kali sweep v${VERSION} ${HOST} ${STAMP} (Risk ${RISK_SCORE}/100)" "$NOTIFY_EMAIL" < "$SUM/summary.txt" || true
    elif command -v mailx >/dev/null 2>&1; then
      mailx -s "Kali sweep v${VERSION} ${HOST} ${STAMP} (Risk ${RISK_SCORE}/100)" "$NOTIFY_EMAIL" < "$SUM/summary.txt" || true
    else
      warn "mail/mailx not found; cannot send email."
    fi
  fi

  # Webhook with exponential backoff
  if [[ -n "$WEBHOOK_URL" ]]; then
    if command -v curl >/dev/null 2>&1; then
      sleep_s="$WEBHOOK_RETRY_SLEEP"
      for i in $(seq 1 "$WEBHOOK_RETRIES"); do
        curl -sS -X POST -H "Content-Type: application/json" --data @"$SUM/summary.json" "$WEBHOOK_URL" >/dev/null && break
        sleep "$sleep_s"
        sleep_s=$(( sleep_s * WEBHOOK_BACKOFF ))
        [[ "$sleep_s" -gt "$WEBHOOK_MAX_SLEEP" ]] && sleep_s="$WEBHOOK_MAX_SLEEP"
      done || true
    else
      warn "curl not found; cannot POST webhook."
    fi
  fi
else
  vlog "Risk score $RISK_SCORE < notify threshold $NOTIFY_THRESHOLD; skipping notifications."
fi

EXIT_CODE=0
if [[ "$RISK_SCORE" -ge "$HIGH_RISK_THRESHOLD" ]]; then
  EXIT_CODE=2
fi

log "Sweep complete. Summary: $SUM/summary.txt"
[[ "$TAR_OK" -eq 1 ]] && log "Archive: $OUT.tar.gz"
exit "$EXIT_CODE"
