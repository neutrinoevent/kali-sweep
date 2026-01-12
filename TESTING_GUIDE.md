# 🧪 Testing & Validation Guide
## kali-sweep v3.2.1

**Purpose:** Repeatable checks to confirm kali-sweep is installed correctly, runs safely, and produces the expected outputs.

This guide is written to match the **public repo contents** and avoids references to private/internal tooling.

---

## 1) Prerequisites

- Kali Linux / Debian-based system
- Root access (kali-sweep is intended to run as root)
- Optional but recommended: `jq` for JSON viewing

Install `jq` if you want JSON inspection:
```bash
sudo apt update
sudo apt install -y jq
```

---

## 2) Installation validation

### A) If installed from DEB
```bash
kali-sweep --version
command -v kali-sweep
ls -l /usr/sbin/kali-sweep
ls -l /etc/kali-sweep.conf
```

Expected:
- `kali-sweep --version` prints `3.2.1`
- `/usr/sbin/kali-sweep` exists and is executable
- `/etc/kali-sweep.conf` exists (if installed via package)

### B) If installed manually from source
```bash
sudo install -m 0755 kali_sweep_v3_2_1.sh /usr/sbin/kali-sweep
sudo /usr/sbin/kali-sweep --version
```

---

## 3) Safe first run (dry-run)

Run a dry-run to confirm argument parsing + logging without making disruptive changes:

```bash
sudo kali-sweep --dry-run --verbose
```

Expected:
- Exit code `0` (unless your script uses a different dry-run policy)
- Output indicates actions that *would* be performed
- No new report directory should be created under `/var/log/kali-sweep/`

Check exit code:
```bash
echo $?
```

---

## 4) Full run validation (creates a report)

Run a normal sweep:
```bash
sudo kali-sweep --verbose
```

Locate the latest report directory:
```bash
LATEST=$(sudo ls -dt /var/log/kali-sweep/*_* 2>/dev/null | head -1)
echo "Latest report: $LATEST"
```

Confirm expected outputs:
```bash
sudo test -f "$LATEST/summary/summary.txt" && echo "OK: summary.txt"
sudo test -f "$LATEST/summary/summary.json" && echo "OK: summary.json"
sudo test -d "$LATEST/network" && echo "OK: network/"
sudo test -d "$LATEST/processes" && echo "OK: processes/"
sudo test -d "$LATEST/persistence" && echo "OK: persistence/"
sudo test -d "$LATEST/filesystem" && echo "OK: filesystem/"
sudo test -d "$LATEST/logs" && echo "OK: logs/"
```

If `jq` is installed:
```bash
sudo jq . "$LATEST/summary/summary.json" | head
```

---

## 5) Baseline workflow validation

Create a baseline in a known-good state:
```bash
sudo kali-sweep --baseline /root/kali-baseline --paranoid
```

Then run compare mode:
```bash
sudo kali-sweep --baseline /root/kali-baseline
```

Confirm `diff/` exists for the latest report:
```bash
LATEST=$(sudo ls -dt /var/log/kali-sweep/*_* 2>/dev/null | head -1)
sudo ls -la "$LATEST/diff" 2>/dev/null || echo "No diff/ directory (compare may be disabled or unchanged)."
```

---

## 6) Systemd timer validation (if packaged)

Check timer and recent runs:
```bash
sudo systemctl status kali-sweep.timer --no-pager
sudo systemctl list-timers --all | grep -i kali-sweep || true
sudo journalctl -u kali-sweep.service -n 50 --no-pager
```

If you want to enable and start the timer:
```bash
sudo systemctl enable --now kali-sweep.timer
```

---

## 7) Exit code behavior

kali-sweep uses exit codes for automation:
- `0` = success / low-to-medium risk (normal operation)
- `1` = execution error (operator attention required)
- `2` = completed successfully but **high risk detected** (investigate using `RUNBOOK.md`)

Validate exit codes with a normal run:
```bash
sudo kali-sweep --quiet
echo "exit=$?"
```

---

## 8) Common troubleshooting checks

### A) “No report directory created”
- If you ran `--dry-run`, that’s expected.
- Otherwise, check logs:
  ```bash
  sudo journalctl -u kali-sweep.service -n 200 --no-pager
  ```

### B) “Timer not active”
- Enable it:
  ```bash
  sudo systemctl enable --now kali-sweep.timer
  ```

### C) “JSON looks empty”
- Open the human-readable summary:
  ```bash
  LATEST=$(sudo ls -dt /var/log/kali-sweep/*_* 2>/dev/null | head -1)
  sudo sed -n '1,200p' "$LATEST/summary/summary.txt"
  ```

---

## 9) Minimal acceptance checklist (release readiness)

- [ ] `kali-sweep --version` reports `3.2.1`
- [ ] `sudo kali-sweep --dry-run --verbose` completes without error
- [ ] `sudo kali-sweep --verbose` creates a report directory under `/var/log/kali-sweep/`
- [ ] `summary/summary.txt` and `summary/summary.json` exist
- [ ] Baseline creation works (`--baseline ... --paranoid`)
- [ ] Compare run works (`--baseline ...`)
- [ ] If using systemd: timer is enabled and logs appear in `journalctl`

---

**Last Updated:** 2026-01-11  
**Version:** 3.2.1
