# kali-sweep v3.2.1 - Complete Package Index

**Project Status:** ✅ Production Ready  
**Build Date:** 2026-01-08  
**Total Lines:** ~3,700 (code + documentation)

---

## 📦 COMPLETE PACKAGE CONTENTS

### 🔧 Core Components

1. **kali_sweep_v3_2_1.sh** (1,100+ lines)
   - Main security sweep script
   - Full feature set with paranoid mode
   - Safe config parsing, atomic locking
   - Risk scoring and notifications
   - Baseline/compare functionality

### 📚 Documentation (2,000+ lines)

2. **README.md** (~400 lines)
   - Feature overview
   - Installation guide
   - Configuration examples
   - Usage patterns
   - Troubleshooting

3. **DEPLOYMENT.md** (~600 lines)
   - Multiple deployment options
   - Configuration deep-dive
   - Scheduling (systemd/cron)
   - Multi-host deployment
   - Monitoring & alerting
   - Production checklist

4. **RUNBOOK.md** (~500 lines)
   - 5-minute triage workflow
   - Step-by-step incident response
   - Containment procedures
   - Forensics guide
   - Common attack scenarios
   - Escalation procedures

5. **QUICKREF.md** (~300 lines)
   - Common commands
   - Quick triage steps
   - One-liners
   - Emergency procedures
   - **PRINT THIS FOR YOUR DESK**

6. **PROJECT_SUMMARY.md** (~600 lines)
   - Complete project overview
   - Configuration checklist
   - Testing checklist
   - Troubleshooting guide
   - Enhancement ideas

7. **README_PROJECT.md** (~200 lines)
   - Main project README
   - Quick start (30 seconds)
   - Common use cases
   - Learning path

### 🛠️ Build & Deploy Tools (800+ lines)

8. **prepare_package.sh** (~350 lines)
   - **USE THIS TO BUILD PACKAGE**
   - Stages all files
   - Creates DEBIAN structure
   - Builds .deb package
   - Provides install instructions

9. **build_deb.sh** (~200 lines)
   - Alternative package builder
   - Automated DEB creation
   - Version stamping

10. **verify_install.sh** (~250 lines)
    - Post-install verification
    - 10-step checklist
    - Color-coded output
    - Returns exit code

---

## 🚀 QUICK START GUIDE

### Option 1: Package Install (Recommended)

```bash
# 1. Build package
chmod +x prepare_package.sh
./prepare_package.sh

# 2. Install
sudo dpkg -i staging/kali-sweep_3.2.1-1.deb

# 3. Verify
chmod +x verify_install.sh
sudo ./verify_install.sh

# 4. Configure
sudo vim /etc/kali-sweep.conf

# 5. Test
sudo kali-sweep --dry-run --verbose

# 6. Start
sudo systemctl start kali-sweep.timer
```

### Option 2: Manual Install

```bash
sudo cp kali_sweep_v3_2_1.sh /usr/sbin/kali-sweep
sudo chmod 0755 /usr/sbin/kali-sweep
sudo kali-sweep --help
```

---

## 📋 FILE REFERENCE

| File | Size | Purpose | When to Use |
|------|------|---------|-------------|
| `kali_sweep_v3_2_1.sh` | ~50KB | Main script | Always (core component) |
| `README.md` | ~13KB | User docs | First read |
| `DEPLOYMENT.md` | ~13KB | Ops guide | Before deploying |
| `RUNBOOK.md` | ~11KB | IR procedures | During incidents |
| `QUICKREF.md` | ~8KB | Quick ref | Daily operations |
| `PROJECT_SUMMARY.md` | ~16KB | Complete overview | Project understanding |
| `README_PROJECT.md` | ~10KB | Main README | Quick start |
| `prepare_package.sh` | ~10KB | Package builder | Building DEB |
| `build_deb.sh` | ~7KB | Alt builder | Alternative method |
| `verify_install.sh` | ~5KB | Verification | Post-install |

**Total Package Size:** ~143KB (uncompressed)

---

## 🎯 RECOMMENDED READING ORDER

### For First-Time Users
1. `README_PROJECT.md` (Quick overview)
2. `README.md` (Full features)
3. Install via `prepare_package.sh`
4. `QUICKREF.md` (Keep handy)

### For System Administrators
1. `README_PROJECT.md`
2. `DEPLOYMENT.md` (Complete guide)
3. Install and configure
4. `RUNBOOK.md` (For team)

### For Incident Responders
1. `QUICKREF.md` (Print this)
2. `RUNBOOK.md` (Study scenarios)
3. Practice on test VM
4. Keep both accessible 24/7

### For Complete Understanding
1. `PROJECT_SUMMARY.md` (Complete overview)
2. All other docs
3. Read the script itself (well-commented)

---

## 🔍 KEY FEATURES

### Detection
- ✅ Suspicious processes (shells, reverse shells, obfuscated commands)
- ✅ Unusual network connections (IPv4/IPv6 aware)
- ✅ Recently modified system binaries
- ✅ Persistence mechanisms (systemd, cron, SSH keys, user units)
- ✅ Hidden files and directories
- ✅ LD_PRELOAD abuse
- ✅ SUID/SGID changes (paranoid mode)
- ✅ Package integrity violations (paranoid mode)

### Response
- ✅ DNS cache flush
- ✅ Route cache flush
- ✅ NetworkManager restart
- ✅ VPN tunnel bounce (tun0/wg0)
- ✅ Optional interactive kill
- ✅ Cache drops
- ✅ Optional UFW lockdown (paranoid)

### Automation
- ✅ Risk scoring (0-100)
- ✅ Exit codes (0=low, 1=error, 2=high risk)
- ✅ Email notifications
- ✅ Webhook integration
- ✅ Syslog integration
- ✅ JSON output for SIEM
- ✅ Systemd timer ready
- ✅ Atomic locking

### Safety
- ✅ Safe config parsing (no source/eval)
- ✅ Dry-run mode
- ✅ Config validation
- ✅ Minimal environment execution (paranoid)
- ✅ Protected log directories (0700)
- ✅ Conffile preservation (DEB package)

---

## ⚙️ CONFIGURATION QUICK REFERENCE

```bash
# /etc/kali-sweep.conf

# === ESSENTIAL ===
SINCE_HOURS=12                          # Lookback window
PARALLEL=1                              # Faster on multi-core
COMMON_PORTS="22,53,80,443,..."         # Add YOUR ports

# === RISK SCORING ===
NOTIFY_THRESHOLD=30                     # Alert threshold
HIGH_RISK_THRESHOLD=50                  # Exit 2 threshold

# === NOTIFICATIONS ===
NOTIFY_EMAIL="alerts@example.invalid"     # Optional
WEBHOOK_URL="https://..."                # Optional
SYSLOG=1                                 # Recommended

# === BASELINE ===
COMPARE_DIR="/root/kali-baseline"       # Optional

# === PARANOID MODE ===
PARANOID=0                               # 1 = slow but thorough
```

---

## 📊 OUTPUT STRUCTURE

```
/var/log/kali-sweep/hostname_YYYYMMDD_HHMMSS/
├── network/         # IP, routes, sockets, connections
├── processes/       # Process trees, suspicious patterns
├── persistence/     # Systemd, cron, SSH, LD_PRELOAD
├── filesystem/      # Recent changes, hidden files, SUID
├── logs/            # Journal extracts
├── integrity/       # Binary hashes, dpkg verify
├── summary/         # summary.txt, summary.json
└── diff/            # Baseline comparisons (if enabled)

Also: hostname_YYYYMMDD_HHMMSS.tar.gz + .sha256
```

---

## 🎓 SKILL LEVELS

### Beginner (Just Starting)
**Use:** `README_PROJECT.md`, `QUICKREF.md`  
**Install:** DEB package via `prepare_package.sh`  
**Run:** Manual sweeps, review summaries  
**Learn:** What reports contain, risk scoring

### Intermediate (Regular User)
**Use:** `DEPLOYMENT.md`, scheduled sweeps  
**Install:** Systemd timer or cron  
**Run:** Baseline/compare mode  
**Learn:** Tuning thresholds, notification setup

### Advanced (IR/Analyst)
**Use:** `RUNBOOK.md`, paranoid mode  
**Install:** Fleet deployment (Ansible)  
**Run:** Incident investigations  
**Learn:** Triage workflows, forensic analysis

### Expert (Developer/Architect)
**Use:** All docs, script source  
**Install:** Custom modifications  
**Run:** SIEM integration, custom rules  
**Learn:** Extending functionality, correlation

---

## 🐛 COMMON ISSUES & FIXES

| Issue | Solution | See |
|-------|----------|-----|
| Lock busy | `rm /var/lock/kali-sweep.lock` | DEPLOYMENT.md |
| Too slow | `SINCE_HOURS=6` + `PARALLEL=1` | QUICKREF.md |
| False positives | Adjust `COMMON_PORTS` | README.md |
| Email not working | Install `mailutils` or use webhook | DEPLOYMENT.md |
| Timer not running | `systemctl enable kali-sweep.timer` | QUICKREF.md |
| High disk usage | Configure logrotate | DEPLOYMENT.md |

---

## 🔒 SECURITY BEST PRACTICES

### Before Deployment
- [ ] Review script source
- [ ] Test in isolated VM
- [ ] Configure `COMMON_PORTS` for environment
- [ ] Set appropriate thresholds
- [ ] Enable notifications
- [ ] Create baseline in known-good state

### During Operations
- [ ] Review reports weekly
- [ ] Update baseline monthly
- [ ] Monitor disk usage
- [ ] Test notifications periodically
- [ ] Keep team trained on RUNBOOK
- [ ] Archive high-risk reports

### For Incidents
- [ ] Follow RUNBOOK.md procedures
- [ ] Preserve evidence
- [ ] Document timeline
- [ ] Escalate if needed
- [ ] Post-incident review
- [ ] Update baselines

---

## 📞 GETTING HELP

### Documentation
1. **Quick start:** `README_PROJECT.md`
2. **Features:** `README.md`
3. **Deployment:** `DEPLOYMENT.md`
4. **Incidents:** `RUNBOOK.md`
5. **Daily ops:** `QUICKREF.md`
6. **Everything:** `PROJECT_SUMMARY.md`

### Diagnostics
```bash
sudo kali-sweep --dry-run --verbose
sudo journalctl -u kali-sweep.service -n 100
cat /var/log/kali-sweep/*/summary/summary.txt
```

### Community
- Kali Forums: https://forums.kali.org/
- r/Kalilinux: https://reddit.com/r/Kalilinux
- r/AskNetsec: https://reddit.com/r/AskNetsec

---

## ✅ DEPLOYMENT CHECKLIST

### Pre-Deployment
- [ ] Read `README_PROJECT.md`
- [ ] Review `DEPLOYMENT.md`
- [ ] Test on VM first
- [ ] Configure for environment
- [ ] Create baseline
- [ ] Test notifications

### Installation
- [ ] Build package: `./prepare_package.sh`
- [ ] Install: `sudo dpkg -i ...`
- [ ] Verify: `./verify_install.sh`
- [ ] Configure: `/etc/kali-sweep.conf`
- [ ] Test: `sudo kali-sweep --dry-run`

### Post-Installation
- [ ] Schedule sweeps (timer/cron)
- [ ] Enable baseline comparison
- [ ] Configure monitoring
- [ ] Distribute RUNBOOK to team
- [ ] Print QUICKREF for desks
- [ ] Monitor first week

### Production Ready
- [ ] All checks passing
- [ ] Team trained
- [ ] Alerts working
- [ ] Logs rotating
- [ ] Baseline current
- [ ] Documentation accessible

---

## 🎉 PROJECT STATISTICS

- **Total Files:** 10
- **Total Lines:** ~3,700
- **Code:** ~1,600 lines (scripts)
- **Documentation:** ~2,100 lines
- **Languages:** Bash, Markdown
- **Dependencies:** Standard Linux tools
- **Package Size:** ~143KB (uncompressed)
- **DEB Package:** ~40KB (compressed)

---

## 🚀 NEXT STEPS

1. ✅ **Install** - Use `prepare_package.sh`
2. ✅ **Configure** - Edit `/etc/kali-sweep.conf`
3. ✅ **Test** - Run `--dry-run --verbose`
4. ✅ **Baseline** - Create known-good snapshot
5. ✅ **Schedule** - Enable timer/cron
6. ✅ **Train** - Distribute RUNBOOK to team
7. ✅ **Monitor** - Watch first week of runs
8. ✅ **Tune** - Adjust thresholds as needed

---

## 📜 LICENSE

MIT License - See `copyright` in DEB package or documentation.

---

## 🙏 ACKNOWLEDGMENTS

This project provides a defensive-first approach to host security on Kali Linux systems. It's designed to complement (not replace) other security tools like:

- Antivirus (ClamAV)
- HIDS (AIDE, Tripwire)
- Network monitoring (Wireshark, Zeek)
- Log analysis (SIEM)
- Configuration management (Ansible, Puppet)

---

**kali-sweep v3.2.1**  
**Status:** ✅ Production Ready  
**Build:** 2026-01-08  

**Ready for deployment. Good hunting! 🛡️**

---

*End of Index*
