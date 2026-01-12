# kali-sweep Incident Response Runbook

**Purpose:** Guide for operators responding to high-risk kali-sweep alerts (exit code 2 or risk score ≥ threshold).

---

## Quick Reference

### Severity Levels

| Risk Score | Severity | Action Required |
|------------|----------|----------------|
| 0-29 | **Low** | No action (normal operations) |
| 30-49 | **Medium** | Review within 24h |
| 50-74 | **High** | Investigate immediately |
| 75-100 | **Critical** | Incident response protocol |

### Alert Sources

1. **Exit code 2** from systemd service
2. **Email alert** (if configured)
3. **Webhook notification** (if configured)
4. **Syslog entry** with `authpriv.notice` or higher

---

## Response Workflow

### Step 1: Locate the Report

Find the most recent report:

```bash
# Find latest report directory
LATEST=$(sudo ls -dt /var/log/kali-sweep/*_* 2>/dev/null | head -1)
echo "Latest report: $LATEST"

# Quick summary
sudo cat "$LATEST/summary/summary.txt"
```

### Step 2: Triage (5 minutes)

Check these files in order of priority:

#### 2.1 Summary & Risk Assessment

```bash
# View summary
sudo cat "$LATEST/summary/summary.txt"

# View JSON for automation
sudo jq . "$LATEST/summary/summary.json"
```

**Key fields:**
- `risk_score` - Overall risk (0-100)
- `suspicious_process_matches` - Potential backdoors/shells
- `established_uncommon_ports_lines` - Unusual outbound connections
- `recent_system_executables` - Binary modifications
- `diff_nonempty_files` - Baseline violations

#### 2.2 Suspicious Processes

```bash
# Check for shell activity, reverse shells, etc.
sudo cat "$LATEST/processes/suspicious_process_patterns.txt"
```

**Red flags:**
- `nc -e`, `socat`, reverse shells
- Python/Perl/Ruby one-liners
- `bash -i`, `sh -i` spawned from unexpected parents
- Obfuscated commands (`base64`, `openssl enc`)

**Immediate action if found:**
```bash
# Kill suspicious PID (from the report)
sudo kill -9 <PID>

# Block outbound if needed
sudo ufw deny out to <IP>
```

#### 2.3 Network Connections

```bash
# Unusual established connections
cat "$LATEST/network/established_uncommon_ports.txt"
```

**Red flags:**
- Connections to non-common ports (outside your `COMMON_PORTS` list)
- High ports (>1024) to external IPs
- Connections to known C2 infrastructure

**Immediate action:**
```bash
# Block suspicious IP
sudo ufw deny out to <IP>

# Drop all routes if critical
sudo ip route flush cache
```

#### 2.4 Persistence Mechanisms

```bash
# Check systemd units
cat "$LATEST/persistence/systemd_enabled_units.txt"

# Check timers
cat "$LATEST/persistence/systemd_timers.txt"

# Check cron
cat "$LATEST/persistence/cron_ls.txt"
cat "$LATEST/persistence/user_crontab.txt"

# Check user systemd units
cat "$LATEST/persistence/systemd_user_units.txt"

# Check LD_PRELOAD abuse
cat "$LATEST/persistence/ld_preload_audit.txt"

# Check authorized_keys
cat "$LATEST/persistence/authorized_keys_locations.txt"
```

**Red flags:**
- Unknown systemd units/timers
- Cron jobs you didn't create
- User systemd units (attackers love these)
- LD_PRELOAD in any config
- Unauthorized SSH keys

**Immediate action:**
```bash
# Disable suspicious unit
sudo systemctl disable <unit-name>
sudo systemctl stop <unit-name>

# Remove malicious cron
sudo crontab -e  # or edit /etc/cron.*

# Check all authorized_keys
for f in $(find /home -name authorized_keys); do
    echo "=== $f ==="
    cat "$f"
done
```

#### 2.5 Recent File Changes

```bash
# System executables modified recently
cat "$LATEST/filesystem/recent_exec_system.txt"

# Home directory changes
head -50 "$LATEST/filesystem/recent_home_files_top3000.txt"

# Hidden files
head -50 "$LATEST/filesystem/hidden_files_top3000.txt"
```

**Red flags:**
- `/usr/bin/*`, `/bin/*`, `/sbin/*` modified recently
- New hidden files (`.bash_history` tampering, `.ssh/config` changes)
- Downloads in user directories

#### 2.6 Baseline Violations (if enabled)

```bash
# Check diffs
ls -lh "$LATEST/diff/"
cat "$LATEST/diff/"*.diff.txt
```

**Red flags:**
- Changes to critical binary hashes
- New SUID/SGID files
- dpkg verify failures (paranoid mode)

---

### Step 3: Containment (10 minutes)

If you've identified a threat:

#### 3.1 Network Isolation

```bash
# OPTION 1: Drop all outbound (aggressive)
sudo ufw default deny outgoing
sudo ufw allow out 22  # Keep SSH
sudo ufw reload

# OPTION 2: Block specific IPs
sudo ufw deny out to <IP>
```

#### 3.2 Kill Malicious Processes

```bash
# From suspicious_process_patterns.txt
sudo kill -9 <PID1> <PID2> <PID3>

# Verify
ps aux | grep <process-name>
```

#### 3.3 Disable Persistence

```bash
# Systemd units
sudo systemctl disable --now <malicious-unit>

# Cron
sudo crontab -e  # Remove malicious entries

# User cron
sudo crontab -u <username> -e
```

#### 3.4 Remove Backdoors

```bash
# SSH keys
sudo vim /home/<user>/.ssh/authorized_keys  # Remove unauthorized keys

# LD_PRELOAD (if found)
sudo rm /etc/ld.so.preload  # If malicious
sudo vim /etc/environment   # Remove LD_PRELOAD
```

---

### Step 4: Evidence Collection (15 minutes)

Before cleaning up, preserve evidence:

```bash
# Copy entire report to incident folder
INCIDENT_ID="incident_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "/root/incidents/$INCIDENT_ID"
sudo cp -a "$LATEST" "/root/incidents/$INCIDENT_ID/"

# Create tarball
sudo tar czf "/root/incidents/${INCIDENT_ID}.tar.gz" -C "$LATEST" .

# Document timeline
cat > "/root/incidents/$INCIDENT_ID/timeline.txt" <<'EOF'
Incident ID: <fill>
Detection time: <fill>
Hostname: <fill>
Risk score: <fill>

What triggered the alert:
- <fill>

Containment actions taken:
- <fill>

Evidence preserved:
- kali-sweep report directory (copied)
- journal excerpts
- process/network snapshots

Initial assessment:
- suspected vector: <fill>
- suspected persistence: <fill>
- suspected C2/egress: <fill>

Remediation performed:
- <fill>

Follow-up tasks:
- rotate credentials/keys
- patch/upgrade packages
- re-baseline after clean state is confirmed
EOF
```

---

### Step 5: Forensics (30+ minutes)

Deep dive:

```bash
# Check all listening services
sudo ss -tulpn

# Review recent logins
last -n 100
lastb -n 100  # Failed logins

# Check journal for anomalies
sudo journalctl --since "1 hour ago" -p warning

# Network connections over time
sudo journalctl -u NetworkManager --since "24 hours ago" | grep -i "connected\|disconnected"

# Check running processes
sudo ps auxwwf

# Memory analysis (if needed)
sudo cat /proc/<PID>/cmdline
sudo cat /proc/<PID>/environ
sudo lsof -p <PID>
```

---

### Step 6: Remediation

After containment and evidence collection:

```bash
# Update all packages
sudo apt update && sudo apt upgrade -y

# Run antivirus (if available)
sudo clamscan -r /home /tmp /var/tmp --infected --remove

# Reset compromised accounts
sudo passwd <username>

# Regenerate SSH keys
sudo rm /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server

# Re-baseline
sudo kali-sweep --baseline /root/kali-baseline --paranoid
```

---

### Step 7: Post-Incident

```bash
# Document lessons learned
vim "/root/incidents/$INCIDENT_ID/lessons_learned.txt"

# Update detection rules
# - Add new suspicious patterns to your fork of kali-sweep
# - Adjust COMMON_PORTS if needed
# - Lower NOTIFY_THRESHOLD if you want earlier alerts

# Schedule follow-up sweep
sudo kali-sweep --paranoid --compare /root/kali-baseline
```

---

## Common Scenarios

### Scenario 1: Reverse Shell Detected

**Indicators:**
- `nc -e` or `socat` in suspicious_process_patterns.txt
- Established connection to unusual port

**Actions:**
1. Kill process: `sudo kill -9 <PID>`
2. Block remote IP: `sudo ufw deny out to <IP>`
3. Check parent process: `ps -ef | grep <PID>`
4. Check how it was spawned (cron, systemd, manual)
5. Remove persistence mechanism

### Scenario 2: LD_PRELOAD Rootkit

**Indicators:**
- `/etc/ld.so.preload` exists
- `LD_PRELOAD` in environment files

**Actions:**
1. **DO NOT run untrusted binaries** (rootkit may hook system calls)
2. Boot from live USB
3. Mount filesystem
4. Remove `/etc/ld.so.preload`
5. Check `/lib` and `/usr/lib` for unknown `.so` files
6. Reinstall critical packages: `sudo apt install --reinstall bash coreutils`

### Scenario 3: Unauthorized SSH Access

**Indicators:**
- New authorized_keys entries
- Unusual `last` entries

**Actions:**
1. Remove unauthorized keys: `sudo vim /home/<user>/.ssh/authorized_keys`
2. Check `/root/.ssh/authorized_keys` too
3. Review `~/.ssh/config` for port forwarding
4. Check for SSH tunnels: `ps aux | grep ssh`
5. Rotate SSH host keys
6. Force password changes

### Scenario 4: System Binary Tampering

**Indicators:**
- `recent_exec_system.txt` shows modifications to `/usr/bin/*`, `/bin/*`
- dpkg verify failures

**Actions:**
1. **DO NOT trust system binaries**
2. Boot from live USB
3. Run `sudo debsums -c` from live environment
4. Reinstall affected packages:
   ```bash
   sudo apt install --reinstall <package>
   ```
5. Verify hashes against known-good baseline

---

## Escalation

### When to Escalate

- Risk score ≥ 75
- Multiple persistence mechanisms found
- System binary tampering detected
- Active C2 communication observed
- Rootkit indicators

### Escalation Contacts

```
Project Contact:	alerts@example.invalid
Incident Manager: incident-mgr@example.com
```

### External Resources

- Incident response playbooks (SANS/NIST)
- Kali/Debian admin references
- Internal SOC runbooks and SIEM dashboards

---

## Automation Hooks

### Email alerts (via cron)

```bash
# /etc/cron.d/kali-sweep-monitor
0 */6 * * * root /usr/sbin/kali-sweep --quiet --config /etc/kali-sweep.conf || echo "kali-sweep HIGH RISK" | mail -s "Alert: kali-sweep $(hostname)" alerts@example.invalid
```

### Webhook integration

See `/etc/kali-sweep.conf`:
```
WEBHOOK_URL="https://your-siem.com/api/alerts"
NOTIFY_THRESHOLD=30
```

kali-sweep will POST `summary.json` automatically.

---

## Quick Commands Reference

```bash
# View latest summary
cat $(ls -dt /var/log/kali-sweep/*_*/summary/summary.txt | head -1)

# Check risk score
jq .risk_score $(ls -dt /var/log/kali-sweep/*_*/summary/summary.json | head -1)

# View suspicious processes
cat $(ls -dt /var/log/kali-sweep/*_* | head -1)/processes/suspicious_process_patterns.txt

# Re-run sweep with paranoid mode
sudo kali-sweep --paranoid --parallel --verbose

# Compare to baseline
sudo kali-sweep --compare /root/kali-baseline

# Kill and restart timer
sudo systemctl restart kali-sweep.timer
```

---

## Appendix: Exit Code Handling

kali-sweep exits with:
- `0` = success, low risk
- `1` = script error
- `2` = success, **high risk detected**

Example systemd alert:

```bash
# /etc/systemd/system/kali-sweep.service (add to [Service])
ExecStartPost=/bin/bash -c 'if [ $EXIT_STATUS -eq 2 ]; then echo "HIGH RISK DETECTED" | mail -s "kali-sweep ALERT" alerts@example.invalid; fi'
```

---

**Last Updated:** 2026-01-08
**Version:** 3.2.1
