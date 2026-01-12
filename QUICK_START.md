# Quick Start

Install and run kali-sweep in 5 minutes.

---

## Install

```bash
# Download DEB
wget https://github.com/neutrinoevent/kali-sweep/releases/latest/download/kali-sweep_3.2.1-1.deb

# Install
sudo dpkg -i kali-sweep_3.2.1-1.deb

# Verify
sudo kali-sweep --version
```

---

## Configure

```bash
# Edit config
sudo nano /etc/kali-sweep.conf

# Set your environment
SINCE_HOURS=12
COMMON_PORTS="22,53,80,443,8080,8443"
PARALLEL=1
```

---

## Run

```bash
# First sweep
sudo kali-sweep

# Create baseline
sudo kali-sweep --baseline /root/baseline --paranoid

# View report
LATEST=$(ls -td /var/log/kali-sweep/*/ | head -1)
sudo cat "$LATEST/summary/summary.txt"
```

---

## Schedule

```bash
# Check timer (installed and enabled automatically)
sudo systemctl status kali-sweep.timer

# View logs
sudo journalctl -u kali-sweep.service --since today

# Modify schedule (default: every 6 hours)
sudo systemctl edit kali-sweep.timer
```

---

## Common Commands

```bash
# Basic sweep
sudo kali-sweep

# Verbose + paranoid
sudo kali-sweep -vp

# Compare to baseline
sudo kali-sweep --baseline /root/baseline

# Dry run
sudo kali-sweep --dry-run

# Specific time window
sudo kali-sweep --since-hours 24

# Help
kali-sweep --help
```

---

## Output

Reports: `/var/log/kali-sweep/HOSTNAME_TIMESTAMP/`

```
summary/summary.txt    # Human-readable summary
summary/summary.json   # JSON (risk score, metrics)
network/              # Connections, listening ports
processes/            # Process list
persistence/          # Systemd, cron, etc.
filesystem/           # Modified files
logs/                 # Journal errors
integrity/            # Binary hashes (paranoid mode)
diff/                 # Baseline comparison
```

Archives: `HOSTNAME_TIMESTAMP.tar.gz` + `.sha256`

---

## Baseline Workflow

```bash
# 1. Clean state - create baseline
sudo kali-sweep --baseline /root/baseline --paranoid

# 2. After activity/time - compare
sudo kali-sweep --baseline /root/baseline

# 3. View differences
sudo cat /var/log/kali-sweep/*/diff/*.diff
```

---

## Risk Score

0-100 score based on:
- Listening ports
- Process patterns
- Modified binaries
- Persistence mechanisms
- Recent file changes

Thresholds (configurable):
- `< 30`: Normal
- `30-50`: Elevated
- `> 50`: High (exit code 2)

---

## Next Steps

See full documentation:
- [README.md](README.md) - Complete reference
- [DEPLOYMENT.md](DEPLOYMENT.md) - Advanced deployment
- [RUNBOOK.md](RUNBOOK.md) - Operations guide
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing
