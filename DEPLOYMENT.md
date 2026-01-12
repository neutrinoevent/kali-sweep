# kali-sweep Deployment Guide

Complete guide for deploying kali-sweep in production/lab environments.

---

## Prerequisites

### System Requirements

- **OS:** Kali Linux (2024.x or newer) or Debian-based distro
- **Root access:** Required
- **Disk:** ~100MB for package + logs (grows over time)
- **Memory:** Minimal (~50MB during sweep)
- **CPU:** Any (faster with `--parallel` on multi-core)

### Network Requirements

- Outbound access (optional):
  - Port 80/443 for webhooks
  - SMTP (25/587) for email alerts
- No inbound ports required

---

## Deployment Options

### Option 1: Quick Deploy (DEB package)

**Best for:** Standard installations, multiple hosts

```bash
# 1. Download or copy package
scp kali-sweep_3.2.1-1.deb target-host:/tmp/

# 2. Install
sudo dpkg -i /tmp/kali-sweep_3.2.1-1.deb

# 3. Verify
kali-sweep --version  # Basic sanity check
sudo systemctl status kali-sweep.timer --no-pager || true  # If packaged

# 4. Configure
sudo vim /etc/kali-sweep.conf

# 5. Start
sudo systemctl start kali-sweep.timer
sudo systemctl status kali-sweep.timer
```

### Option 2: Manual Install (No package)

**Best for:** Custom deployments, testing

```bash
# 1. Copy script
sudo cp kali_sweep_v3_2_1.sh /usr/sbin/kali-sweep
sudo chmod 0755 /usr/sbin/kali-sweep

# 2. Create config
sudo tee /etc/kali-sweep.conf > /dev/null <<'EOF'
SINCE_HOURS=12
PARALLEL=1
SYSLOG=1
EOF

# 3. Create log directory
sudo mkdir -p /var/log/kali-sweep
sudo chmod 0700 /var/log/kali-sweep

# 4. Test
sudo kali-sweep --dry-run --verbose
sudo kali-sweep --since-hours 1
```

### Option 3: Ansible Playbook

**Best for:** Fleet deployments

```yaml
# kali-sweep.yml
---
- name: Deploy kali-sweep
  hosts: kali_hosts
  become: yes
  tasks:
    - name: Copy package
      copy:
        src: kali-sweep_3.2.1-1.deb
        dest: /tmp/kali-sweep.deb
        mode: '0644'

    - name: Install package
      apt:
        deb: /tmp/kali-sweep.deb
        state: present

    - name: Configure
      copy:
        content: |
          SINCE_HOURS=12
          PARALLEL=1
          SYSLOG=1
          NOTIFY_THRESHOLD=30
          WEBHOOK_URL={{ webhook_url }}
        dest: /etc/kali-sweep.conf
        mode: '0640'

    - name: Enable timer
      systemd:
        name: kali-sweep.timer
        state: started
        enabled: yes
        daemon_reload: yes

    - name: Run verification
      command: /usr/sbin/kali-sweep --dry-run
      register: verify
      failed_when: verify.rc != 0
```

Run:
```bash
ansible-playbook -i inventory.ini kali-sweep.yml -e "webhook_url=https://siem.example.com/hook"
```

---

## Configuration

### Basic Configuration (`/etc/kali-sweep.conf`)

```bash
# Timing
SINCE_HOURS=12              # Lookback window (1-720)
PARALLEL=1                  # Concurrent execution (faster)

# Ports heuristic
# Add your lab/CTF ports here
COMMON_PORTS="22,53,80,443,8080,8443,4444,8000,9001,5000"

# Logging
SYSLOG=1                    # Enable syslog integration
SYSLOG_TAG="kali-sweep"
SYSLOG_PRI="authpriv.notice"

# Risk thresholds
NOTIFY_THRESHOLD=30         # Alert when risk >= 30
HIGH_RISK_THRESHOLD=50      # Exit 2 when risk >= 50
```

### Advanced Configuration

#### Email Alerts

```bash
# Requires: mailutils or bsd-mailx
NOTIFY_EMAIL="alerts@example.invalid"
NOTIFY_THRESHOLD=30
```

Test email:
```bash
echo "test" | mail -s "test from $(hostname)" alerts@example.invalid
```

#### Webhook Integration

```bash
WEBHOOK_URL="https://your-siem.example.com/api/kali-sweep"
WEBHOOK_RETRIES=3
WEBHOOK_RETRY_SLEEP=2
WEBHOOK_BACKOFF=2          # Exponential backoff multiplier
WEBHOOK_MAX_SLEEP=30
NOTIFY_THRESHOLD=30
```

Test webhook:
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"test":"data"}' \
  https://your-siem.example.com/api/kali-sweep
```

#### Paranoid Mode (Automated)

```bash
# Enable in config
PARANOID=1

# Or via environment
KALI_SWEEP_PARANOID=1 kali-sweep
```

**Warning:** Paranoid mode is slower (SUID scan + dpkg verify) but more thorough.

---

## Scheduling

### Systemd Timer (Recommended)

Default schedule: **every 6 hours**

View schedule:
```bash
sudo systemctl list-timers --all | grep kali-sweep
```

Modify schedule:
```bash
sudo systemctl edit kali-sweep.timer
```

Add:
```ini
[Timer]
OnBootSec=5m
OnUnitActiveSec=3h  # Run every 3 hours
```

Reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart kali-sweep.timer
```

### Cron Alternative

If you prefer cron:

```bash
sudo crontab -e
```

Add:
```cron
# Run every 6 hours
0 */6 * * * /usr/sbin/kali-sweep --config /etc/kali-sweep.conf --quiet --parallel --syslog

# Exit code handling
0 */6 * * * /usr/sbin/kali-sweep --quiet || [ $? -eq 2 ] && echo "HIGH RISK" | mail -s "kali-sweep alert" alerts@example.invalid
```

---

## Baselining

### Initial Baseline

Create a clean baseline **immediately after a fresh Kali install** or known-good state:

```bash
# Clean install state
sudo kali-sweep --baseline /root/kali-baseline-clean --since-hours 24 --paranoid
```

### Operational Baseline

Create after your tools/environment is set up:

```bash
# After configuring tools, VPNs, etc.
sudo kali-sweep --baseline /root/kali-baseline-operational --since-hours 24
```

### Scheduled Baseline Updates

Update baseline weekly:

```bash
# Add to root crontab
0 2 * * 0 /usr/sbin/kali-sweep --baseline /root/kali-baseline-operational --quiet
```

### Compare Against Baseline

Every sweep:
```bash
sudo kali-sweep --compare /root/kali-baseline-operational --parallel --syslog
```

Or configure in `/etc/kali-sweep.conf`:
```bash
COMPARE_DIR="/root/kali-baseline-operational"
```

---

## Multi-Host Deployment

### Central Logging (Syslog)

Configure all hosts to send syslog to central server:

**On each Kali host:**
```bash
# /etc/rsyslog.d/50-kali-sweep.conf
authpriv.*  @@syslog-server.example.com:514
```

Restart rsyslog:
```bash
sudo systemctl restart rsyslog
```

**On syslog server:**
```bash
# Parse kali-sweep logs
grep "kali-sweep" /var/log/syslog | grep "risk="
```

### Central Webhook Collector (Example)

If you want webhook ingestion, deploy **any** HTTPS endpoint that can accept a JSON POST and store/forward it to your SIEM (Elastic/Loki/Splunk/etc.). Keep it authenticated (mTLS or a signed token) and rate-limited.

Configure all hosts:

```bash
# /etc/kali-sweep.conf
WEBHOOK_URL="http://collector.example.com:8080/hook"
NOTIFY_THRESHOLD=30
```

### Ansible Fleet Management

```yaml
# fleet-check.yml
---
- name: Check kali-sweep status on fleet
  hosts: kali_hosts
  become: yes
  tasks:
    - name: Get latest risk score
      shell: |
        jq -r .risk_score $(ls -dt /var/log/kali-sweep/*_*/summary/summary.json 2>/dev/null | head -1) || echo "0"
      register: risk
      changed_when: false

    - name: Report high risk
      debug:
        msg: "HIGH RISK: {{ inventory_hostname }} - Score {{ risk.stdout }}"
      when: risk.stdout|int >= 50

    - name: Collect summaries
      fetch:
        src: "{{ item }}"
        dest: "reports/{{ inventory_hostname }}/"
        flat: yes
      with_fileglob:
        - /var/log/kali-sweep/*/summary/summary.json
      when: risk.stdout|int >= 50
```

Run:
```bash
ansible-playbook -i inventory.ini fleet-check.yml
```

---

## Monitoring & Alerting

### Systemd Journal

Watch real-time:
```bash
sudo journalctl -u kali-sweep.service -f
```

Check last run:
```bash
sudo journalctl -u kali-sweep.service -n 100 --no-pager
```

Check timer status:
```bash
sudo systemctl status kali-sweep.timer
```

### Log Analysis

Find high-risk runs:
```bash
# Search syslog
sudo grep "kali-sweep.*risk=" /var/log/syslog | grep -E "risk=[5-9][0-9]|risk=100"

# Or with journalctl
sudo journalctl -t kali-sweep | grep -E "risk=[5-9][0-9]|risk=100"
```

Find recent reports with high risk:
```bash
find /var/log/kali-sweep -name summary.json -mtime -7 -exec sh -c 'score=$(jq -r .risk_score "$1"); if [ "$score" -ge 50 ]; then echo "$1: $score"; fi' _ {} \;
```

### Grafana Dashboard (Advanced)

Parse JSON summaries and visualize:

1. Export logs to Elasticsearch/Loki
2. Query `summary.json` fields
3. Create panels:
   - Risk score over time (line graph)
   - Suspicious process count (bar chart)
   - Recent binary modifications (table)
   - Alert rate (counter)

---

## Backup & Disaster Recovery

### Backup Report Archives

```bash
# Daily backup of reports
0 3 * * * rsync -a /var/log/kali-sweep/ backup-server:/backups/kali-sweep/$(hostname)/
```

### Backup Baselines

```bash
# Include in system backups
/root/kali-baseline-clean/
/root/kali-baseline-operational/
```

### Config Management

```bash
# Track config changes
cd /etc
sudo git init
sudo git add kali-sweep.conf
sudo git commit -m "Initial kali-sweep config"
```

---

## Troubleshooting

### Issue: Sweep takes too long

**Solution:**
```bash
# Reduce lookback window
SINCE_HOURS=6

# Enable parallel mode
PARALLEL=1

# Increase timeouts
TIMEOUT_LONG=300
```

### Issue: Disk space filling up

**Solution:**
```bash
# Enable logrotate (should be automatic with package)
sudo logrotate /etc/logrotate.d/kali-sweep

# Manual cleanup (keep last 30 days)
find /var/log/kali-sweep -type f -mtime +30 -delete
find /var/log/kali-sweep -type d -empty -delete
```

### Issue: False positives

**Solution:**
```bash
# Adjust COMMON_PORTS to include your legitimate services
COMMON_PORTS="22,53,80,443,8080,8443,4444,8000,9001,1337,31337"

# Increase thresholds
NOTIFY_THRESHOLD=50
HIGH_RISK_THRESHOLD=75
```

### Issue: Email not sending

**Solution:**
```bash
# Test mail command
echo "test" | mail -s "test" your@email.com

# If not working, install mailutils
sudo apt install mailutils

# Or use webhook instead
WEBHOOK_URL="https://your-service.com/hook"
```

### Issue: Timer not running

**Solution:**
```bash
# Check status
sudo systemctl status kali-sweep.timer

# Enable if needed
sudo systemctl enable --now kali-sweep.timer

# Check logs
sudo journalctl -u kali-sweep.timer
```

---

## Security Hardening

### Protect Config File

```bash
sudo chown root:root /etc/kali-sweep.conf
sudo chmod 0640 /etc/kali-sweep.conf
```

### Protect Log Directory

```bash
sudo chmod 0700 /var/log/kali-sweep
```

### Restrict Binary Execution

```bash
# Ensure only root can execute
sudo chown root:root /usr/sbin/kali-sweep
sudo chmod 0750 /usr/sbin/kali-sweep
```

### Audit Trail

```bash
# Enable process auditing (auditd)
sudo apt install auditd
sudo auditctl -w /usr/sbin/kali-sweep -p x -k kali-sweep-exec
```

---

## Production Checklist

- [ ] Package installed and verified
- [ ] Config file created (`/etc/kali-sweep.conf`)
- [ ] COMMON_PORTS adjusted for your environment
- [ ] Notifications configured (email/webhook)
- [ ] Thresholds tuned (NOTIFY_THRESHOLD, HIGH_RISK_THRESHOLD)
- [ ] Systemd timer enabled and active
- [ ] Logrotate configured
- [ ] Clean baseline created
- [ ] Comparison mode enabled
- [ ] Test run completed successfully
- [ ] Alerts tested (manual high-risk trigger)
- [ ] Runbook distributed to team
- [ ] Escalation contacts configured

---

## Uninstall

### Remove Package

```bash
# Remove but keep config
sudo apt remove kali-sweep

# Purge everything
sudo apt purge kali-sweep

# Or with dpkg
sudo dpkg -P kali-sweep
```

### Manual Cleanup

```bash
# If installed manually
sudo rm /usr/sbin/kali-sweep
sudo rm /etc/kali-sweep.conf
sudo rm /etc/logrotate.d/kali-sweep
sudo rm /lib/systemd/system/kali-sweep.{service,timer}
sudo systemctl daemon-reload

# Remove logs
sudo rm -rf /var/log/kali-sweep
```

---

## Next Steps

1. **Review** the RUNBOOK.md for incident response procedures
2. **Test** with `--dry-run` first
3. **Baseline** your system in a known-good state
4. **Monitor** logs for the first week
5. **Tune** thresholds based on your environment
6. **Integrate** with your existing SIEM/alerting

---

**Questions? Issues?**
- Check logs: `sudo journalctl -u kali-sweep.service`
- Run verbose: `sudo kali-sweep --verbose`
- Review reports: `/var/log/kali-sweep/`

---

**Version:** 3.2.1  
**Last Updated:** 2026-01-08
