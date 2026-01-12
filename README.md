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

### Install from Source (script-free)
```bash
git clone https://github.com/neutrinoevent/kali-sweep.git
cd kali-sweep
sudo install -m 0755 kali_sweep_v3_2_1.sh /usr/sbin/kali-sweep
sudo kali-sweep --version
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
sudo kali-sweep
sudo kali-sweep --paranoid --verbose
sudo kali-sweep --baseline /root/baseline
sudo kali-sweep --baseline /root/baseline --since-hours 24
sudo kali-sweep --dry-run
```

---

## Configuration

Edit `/etc/kali-sweep.conf`:

```bash
SINCE_HOURS=12
PARANOID=0
PARALLEL=1
COMMON_PORTS="22,53,80,443"
NOTIFY_THRESHOLD=30
HIGH_RISK_THRESHOLD=50
SYSLOG=1
```

---

## Documentation

- **QUICK_START.md**
- **DEPLOYMENT.md**
- **RUNBOOK.md**
- **TESTING_GUIDE.md**
- **QUICKREF.md**

---

## License

GPLv3 – see LICENSE.
