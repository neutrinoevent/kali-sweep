# kali-sweep Quick Reference Card

**Version 3.2.1** | Print this for your desk/lab

---

## Common Commands

```bash
# Help & version
kali-sweep --help
kali-sweep --version

# Basic sweep (12h lookback)
sudo kali-sweep --since-hours 12 --parallel

# Paranoid sweep (slow but thorough)
sudo kali-sweep --paranoid --parallel

# Quick triage (6h)
sudo kali-sweep --since-hours 6

# Dry run (test without executing)
sudo kali-sweep --dry-run --verbose

# With baseline comparison
sudo kali-sweep --compare /root/kali-baseline

# Create/update baseline
sudo kali-sweep --baseline /root/kali-baseline

# Silent mode (cron-friendly)
sudo kali-sweep --quiet --config /etc/kali-sweep.conf
```

---

## Systemd Operations

```bash
# Status
sudo systemctl status kali-sweep.timer
sudo systemctl status kali-sweep.service

# Start/stop timer
sudo systemctl start kali-sweep.timer
sudo systemctl stop kali-sweep.timer

# Enable/disable (auto-start)
sudo systemctl enable kali-sweep.timer
sudo systemctl disable kali-sweep.timer

# View logs
sudo journalctl -u kali-sweep.service -f
sudo journalctl -u kali-sweep.service -n 100 --no-pager

# View timer schedule
sudo systemctl list-timers --all | grep kali-sweep

# Trigger immediate run
sudo systemctl start kali-sweep.service
```

---

## Report Locations

```
/var/log/kali-sweep/<HOST>_<TIMESTAMP>/
  ├── network/           # Network state
  ├── processes/         # Process lists & suspicious patterns
  ├── persistence/       # Systemd, cron, SSH keys
  ├── filesystem/        # Recent changes, hidden files
  ├── logs/              # Journal extracts
  ├── integrity/         # Hashes, dpkg verify
  ├── summary/           # summary.txt, summary.json
  └── diff/              # Baseline comparisons
```

**Note:** `/var/log/kali-sweep/` is root-only (`0700`). Use `sudo` to read reports.


**Key files:**
- `summary/summary.txt` - Human-readable summary
- `summary/summary.json` - Machine-readable
- `processes/suspicious_process_patterns.txt` - Shell activity
- `network/established_uncommon_ports.txt` - Unusual connections
- `diff/*.diff.txt` - Baseline violations

---

## Quick Triage (High-Risk Alert)

```bash
# 1. Find latest report
LATEST=$(sudo ls -dt /var/log/kali-sweep/*_* 2>/dev/null | head -1)

# 2. View summary
sudo cat "$LATEST/summary/summary.txt"

# 3. Check risk score
sudo jq .risk_score "$LATEST/summary/summary.json"

# 4. Review suspicious processes
sudo cat "$LATEST/processes/suspicious_process_patterns.txt"

# 5. Check unusual connections
sudo cat "$LATEST/network/established_uncommon_ports.txt"

# 6. Check persistence
sudo cat "$LATEST/persistence/systemd_enabled_units.txt"

# 7. Review diffs (if baseline enabled)
sudo ls -lh "$LATEST/diff/"
```

---

## Immediate Response (Containment)

```bash
# Kill suspicious process
sudo kill -9 <PID>

# Block outbound IP
sudo ufw deny out to <IP>

# Disable suspicious systemd unit
sudo systemctl disable --now <unit-name>

# Remove malicious cron
sudo crontab -e

# Check SSH keys
cat /root/.ssh/authorized_keys
find /home -name authorized_keys -exec cat {} +

# Network isolation (nuclear option)
sudo ufw default deny outgoing
sudo ufw allow out 22  # Keep SSH
sudo ufw reload
```

---

## Configuration Quick Edit

```bash
# Edit config
sudo vim /etc/kali-sweep.conf

# Common tweaks:
SINCE_HOURS=6              # Shorter lookback
PARALLEL=1                 # Faster on multi-core
COMMON_PORTS="22,53,80,443,4444,8080,8443"  # Add lab ports
NOTIFY_THRESHOLD=30        # Alert at risk >= 30
HIGH_RISK_THRESHOLD=50     # Exit 2 at risk >= 50

# Reload (if timer is running)
sudo systemctl restart kali-sweep.timer
```

---

## Risk Score Interpretation

| Score | Severity | Action |
|-------|----------|--------|
| 0-29  | Low | Normal operations |
| 30-49 | Medium | Review within 24h |
| 50-74 | **High** | Investigate now |
| 75-100| **Critical** | Incident response |

**Exit codes:**
- `0` = Success, low risk
- `1` = Script error
- `2` = **High risk detected** (>= threshold)

---

## Common Issues

**Sweep too slow?**
```bash
SINCE_HOURS=6     # Reduce lookback
PARALLEL=1        # Enable parallel
```

**Too many false positives?**
```bash
# Add your legitimate ports
COMMON_PORTS="22,53,80,443,4444,8080,8443,9001,1337,31337,5000"

# Raise thresholds
NOTIFY_THRESHOLD=50
HIGH_RISK_THRESHOLD=75
```

**Disk filling up?**
```bash
# Cleanup old reports (keep 30 days)
find /var/log/kali-sweep -type f -mtime +30 -delete
find /var/log/kali-sweep -type d -empty -delete

# Or run logrotate manually
sudo logrotate -f /etc/logrotate.d/kali-sweep
```

**Timer not running?**
```bash
sudo systemctl enable --now kali-sweep.timer
sudo systemctl list-timers | grep kali-sweep
```

---

## Baseline Workflow

```bash
# 1. Create initial baseline (clean state)
sudo kali-sweep --baseline /root/kali-baseline --paranoid

# 2. Run regular sweeps with comparison
sudo kali-sweep --compare /root/kali-baseline

# 3. Update baseline (monthly/after major changes)
sudo kali-sweep --baseline /root/kali-baseline
```

---

## One-Liners

```bash
# View all high-risk runs (last 7 days)
find /var/log/kali-sweep -name summary.json -mtime -7 -exec sh -c 'score=$(jq -r .risk_score "$1"); if [ "$score" -ge 50 ]; then echo "$1: $score"; fi' _ {} \;

# Latest risk score
sudo jq -r .risk_score "$(sudo ls -dt /var/log/kali-sweep/*_*/summary/summary.json 2>/dev/null | head -1)"

# Count suspicious processes (last run)
sudo wc -l < "$(sudo ls -dt /var/log/kali-sweep/*_*/processes/suspicious_process_patterns.txt 2>/dev/null | head -1)"

# Search syslog for high-risk
sudo grep "kali-sweep.*risk=" /var/log/syslog | grep -E "risk=[5-9][0-9]|risk=100"

# Archive latest report
tar czf kali-sweep-$(date +%Y%m%d).tar.gz $(ls -dt /var/log/kali-sweep/*_* | head -1)
```

---

## Environment Variable Overrides

```bash
# Override any config setting
sudo KALI_SWEEP_PARANOID=1 kali-sweep
sudo KALI_SWEEP_SINCE_HOURS=6 kali-sweep
sudo KALI_SWEEP_COMMON_PORTS="22,53,80,443,8080" kali-sweep
```

**Available variables:**
- `KALI_SWEEP_PARANOID`
- `KALI_SWEEP_SINCE_HOURS`
- `KALI_SWEEP_PARALLEL`
- `KALI_SWEEP_COMMON_PORTS`
- `KALI_SWEEP_NOTIFY_THRESHOLD`
- `KALI_SWEEP_WEBHOOK_URL`
- `KALI_SWEEP_SYSLOG`

---

## Emergency Procedures

**Suspected compromise:**
1. **DO NOT** trust system binaries
2. Boot from live USB
3. Mount filesystem read-only
4. Extract latest kali-sweep report for forensics
5. Preserve evidence before remediation

**Active C2 detected:**
1. Kill process: `sudo kill -9 <PID>`
2. Block IP: `sudo ufw deny out to <IP>`
3. Disconnect network: `sudo ip link set eth0 down`
4. Escalate to security team

**Rootkit suspected:**
1. **DO NOT run binaries** from compromised system
2. Boot live environment
3. Run `chkrootkit` / `rkhunter` from live
4. Compare system binary hashes
5. Reinstall OS if confirmed

---

## Support & Documentation

```
README.md       - Feature overview & usage
DEPLOYMENT.md   - Installation & config guide
RUNBOOK.md      - Incident response procedures
QUICKREF.md     - This reference card

Config:   /etc/kali-sweep.conf
Logs:     /var/log/kali-sweep/
Binary:   /usr/sbin/kali-sweep
```

**Quick help:**
```bash
kali-sweep --help | less
man systemctl  # For timer operations
```

---

## Pro Tips

- **Run baseline immediately** after fresh install
- **Add lab ports** to COMMON_PORTS (4444, 8080, 9001, etc.)
- **Enable parallel mode** for faster sweeps
- **Review reports weekly**, even if no alerts
- **Archive high-risk reports** for post-mortems
- **Test notifications** before relying on them
- **Update baseline** after legitimate system changes

---

**Print this card or save as `/root/kali-sweep-quickref.txt`**

```bash
# Save for quick access
sudo cp QUICKREF.md /root/kali-sweep-quickref.txt
cat /root/kali-sweep-quickref.txt | less
```

---

*kali-sweep v3.2.1 | 2026-01-08*
