# kali-sweep

**Defensive security sweep for Kali Linux**

[![Version](https://img.shields.io/badge/version-3.2.1-blue)](https://github.com/neutrinoevent/kali-sweep/releases)
[![Tests](https://img.shields.io/badge/tests-60/60-brightgreen)](https://github.com/neutrinoevent/kali-sweep)
[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

Collects structured telemetry, performs light disruption/hardening, supports baseline/diff workflows, and emits summary outputs.

**Author:** Alexander Nichols, Old Dominion University  
**License:** GPLv3

---

## Installation

### Quick Install (Recommended)
```bash
wget https://github.com/neutrinoevent/kali-sweep/releases/latest/download/kali-sweep_3.2.1-1.deb
sudo dpkg -i kali-sweep_3.2.1-1.deb
```

### Build from Source
```bash
git clone https://github.com/neutrinoevent/kali-sweep.git
cd kali-sweep
./prepare_package.sh
sudo dpkg -i staging/kali-sweep_3.2.1-1.deb
```

### What Gets Installed
- **Binary:** `/usr/sbin/kali-sweep`
- **Config:** `/etc/kali-sweep.conf`
- **Timer:** Systemd timer (runs every 6 hours)
- **Logs:** `/var/log/kali-sweep/` (root-only, 0700)
- **Docs:** `/usr/share/doc/kali-sweep/`

---

## Usage

```bash
# Basic sweep
sudo kali-sweep

# With options
sudo kali-sweep --paranoid --verbose

# Create baseline
sudo kali-sweep --baseline /root/baseline

# Compare against baseline
sudo kali-sweep --baseline /root/baseline --since-hours 24

# Dry run
sudo kali-sweep --dry-run
```

### Options
```
-h, --help           Show help
-v, --verbose        Verbose output
-p, --paranoid       Paranoid mode (integrity checks)
-n, --dry-run        Test without changes
-c, --config FILE    Config file (default: /etc/kali-sweep.conf)
-b, --baseline DIR   Baseline directory for comparison
-s, --since-hours N  Look back N hours (default: 12)
--parallel           Parallel execution
--quiet              Minimal output
--syslog             Log to syslog
--version            Show version
```

---

## Configuration

Edit `/etc/kali-sweep.conf`:

```bash
SINCE_HOURS=12                    # Lookback window
PARANOID=0                        # 0=normal, 1=paranoid
PARALLEL=1                        # Parallel execution
COMMON_PORTS="22,53,80,443"       # Ports to monitor
NOTIFY_THRESHOLD=30               # Risk score threshold
HIGH_RISK_THRESHOLD=50            # Exit code 2 threshold
SYSLOG=1                          # Syslog integration
```

---

## What It Does

### Data Collection
- Active network connections and listening ports
- Process list with command lines
- Systemd units and timers
- Boot persistence (systemd, cron, rc.local, etc.)
- Modified executables (within time window)
- Hidden files in /home
- Journal errors/warnings
- Binary hashes (critical system files)

### Light Hardening (Non-Paranoid)
- Drop caches (performance/forensics)
- Clear various history files (optional, configurable)

### Paranoid Mode
- Full binary integrity checks
- Extended persistence enumeration
- Deeper filesystem analysis

### Output Structure
```
/var/log/kali-sweep/HOSTNAME_TIMESTAMP/
├── summary/
│   ├── summary.txt          # Human-readable summary
│   └── summary.json         # Machine-readable (risk score, metrics)
├── network/
│   ├── connections.txt
│   ├── listening.txt
│   └── routes.txt
├── processes/
│   └── ps-aux.txt
├── persistence/
│   ├── systemd-units.txt
│   ├── cron.txt
│   └── rc-local.txt
├── filesystem/
│   ├── modified-executables.txt
│   └── hidden-files.txt
├── logs/
│   └── journal-errors.txt
├── integrity/
│   └── binary-hashes.txt
└── diff/                    # If baseline provided
    └── *.diff
```

Reports are archived to `.tar.gz` with SHA256 checksums.

---

## Systemd Timer

Installed timer runs every 6 hours:

```bash
# Check status
sudo systemctl status kali-sweep.timer

# View logs
sudo journalctl -u kali-sweep.service

# Disable timer
sudo systemctl disable kali-sweep.timer

# Modify schedule
sudo systemctl edit kali-sweep.timer
```

---

## Baseline Workflow

```bash
# Create baseline (clean state)
sudo kali-sweep --baseline /root/baseline --paranoid

# Later, compare current state
sudo kali-sweep --baseline /root/baseline

# View differences
sudo cat /var/log/kali-sweep/*/diff/*.diff
```

---

## Risk Scoring

Risk score (0-100) based on:
- Listening ports on uncommon services
- Suspicious processes
- Modified system binaries
- Unusual persistence mechanisms
- Recent file modifications

**Thresholds:**
- `< 30`: Normal
- `30-50`: Elevated
- `> 50`: High (exits with code 2)

Configure thresholds in `/etc/kali-sweep.conf`.

---

## Exit Codes

- `0`: Normal (risk < HIGH_RISK_THRESHOLD)
- `1`: Error during execution
- `2`: High risk detected (risk >= HIGH_RISK_THRESHOLD)

---

## Testing

```bash
# Quick verification
sudo ./verify_install.sh

# Comprehensive tests (60 tests)
sudo ./comprehensive-test.sh

# File audit
./audit-files.sh
```

---

## Documentation

- **[QUICK_START.md](QUICK_START.md)** - 5-minute start
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment guide
- **[RUNBOOK.md](RUNBOOK.md)** - Operations reference
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Testing documentation
- **[QUICKREF.md](QUICKREF.md)** - Quick reference

---

## Dependencies

**Required** (auto-installed):
- bash >= 4.0
- coreutils, findutils, grep, gawk
- procps, iproute2, systemd, util-linux, tar

**Optional** (recommended):
- curl (webhook notifications)
- mailutils (email notifications)
- ufw (enhanced security checks)

---

## License

GPLv3 - See [LICENSE](LICENSE)

Free to use, modify, and distribute. Derivative works must also be GPLv3.

---

## Contributing

Issues and pull requests welcome.

---

## Author

Alexander Nichols  
Old Dominion University

---

**For penetration testing and security research. Use responsibly.**
