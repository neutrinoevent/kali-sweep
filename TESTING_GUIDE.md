# 🧪 Complete Testing & Audit Guide
## kali-sweep v3.2.1 Validation Suite

**Version:** 2.0 - Tailored to Current Installation  
**Date:** January 11, 2026

---

## 📋 Overview

You now have two powerful tools for validating your kali-sweep installation:

1. **comprehensive-test.sh** - Full functionality testing (50+ tests)
2. **audit-files.sh** - File structure analysis and cleanup guidance

Both are specifically tailored to your actual installation state and will check for all 9 critical bug fixes we implemented.

---

## ⚠️ CRITICAL: Sync Source Code First!

**Before running any tests, sync your source code:**

```bash
cd ~/field-scripts/kali-sweep

# Backup old version
mv kali_sweep_v3_2_1.sh kali_sweep_v3_2_1.sh.outdated

# Copy working version from installed binary
sudo cp /usr/sbin/kali-sweep kali_sweep_v3_2_1.sh

# Fix ownership
sudo chown $USER:$USER kali_sweep_v3_2_1.sh
chmod 644 kali_sweep_v3_2_1.sh

# Verify sync
sha256sum kali_sweep_v3_2_1.sh
sudo sha256sum /usr/sbin/kali-sweep
# ☝️ These should match!
```

**Why this matters:** The test suite will FAIL on the first test if source isn't synced. This is intentional - it catches the #1 issue.

---

## 🧪 Part 1: Comprehensive Testing

### What It Tests

**10 Test Categories, 50+ Individual Tests:**

1. **Source Code Sync** (3 tests)
   - Development file exists
   - Installed binary exists  
   - SHA256 hashes match (CRITICAL!)

2. **Bug Fix Validation** (9 tests)
   - ✅ vlog() has return 0
   - ✅ run_out() has dry-run handling
   - ✅ apply_env_overrides() has || true
   - ✅ SINCE_HOURS uses positive logic
   - ✅ Integer validation properly nested
   - ✅ flock has proper indentation
   - ✅ Helpful logging messages
   - ✅ add_to_baseline() has return 0
   - ✅ Summary uses command grouping

3. **Installation Validation** (8 tests)
   - Package installed
   - Binary executable
   - Version correct (3.2.1)
   - Config file exists
   - Log directory with 700 permissions
   - Systemd timer registered
   - Timer enabled
   - All dependencies present

4. **Dry-Run Tests** (4 tests)
   - Basic dry-run works
   - Verbose mode
   - Paranoid mode
   - Doesn't create actual reports

5. **Real Sweep Tests** (18 tests)
   - Sweep executes successfully
   - 8 directories created (summary, network, processes, etc.)
   - summary.txt exists and valid
   - summary.json exists and valid JSON
   - Tarball created
   - SHA256 checksum created
   - Version in summary
   - Risk score calculated
   - Runtime recorded
   - Tarball status shown

6. **Baseline & Compare** (5 tests)
   - Baseline creation
   - Baseline directory exists
   - Critical files in baseline
   - Compare executes
   - Diff directory created

7. **Systemd Timer** (5 tests)
   - Timer unit exists
   - Service unit exists
   - Timer enabled
   - Timer active
   - Configuration valid

8. **Configuration** (3 tests)
   - Config readable
   - Config has valid syntax
   - Environment variables work

9. **Error Handling** (3 tests)
   - Invalid arguments rejected
   - Help works
   - Version works

10. **Performance** (1 test)
    - Sweep completes in reasonable time (<120s)

---

### How to Run

```bash
cd ~/field-scripts/kali-sweep

# Make executable
chmod +x comprehensive-test.sh

# Run full test suite (recommended)
sudo ./comprehensive-test.sh --keep-logs
```

### Options

```bash
# Keep test logs (recommended for first run)
sudo ./comprehensive-test.sh --keep-logs

# Skip destructive tests (safer, but less thorough)
sudo ./comprehensive-test.sh --skip-destructive

# Both options
sudo ./comprehensive-test.sh --keep-logs --skip-destructive

# Get help
sudo ./comprehensive-test.sh --help
```

### Output

Creates:
- `test-YYYYMMDD_HHMMSS.log` - Full detailed log
- `test-results-YYYYMMDD_HHMMSS/` directory containing:
  - `test-report.txt` - Summary report
  - Copy of detailed log
  - Latest sweep summary for reference

### Expected Results

**If source is synced:**
```
╔════════════════════════════════════════════════════════════╗
║  kali-sweep Comprehensive Test Suite v2.0.0            ║
╚════════════════════════════════════════════════════════════╝

========================================
Source Code Sync Validation
========================================
  Testing: Development source exists ... [PASS] PASSED
  Testing: Installed binary exists ... [PASS] PASSED
  Testing: Source and binary match (SHA256) ... [PASS] PASSED
  ✓ Source code is SYNCED!
  Testing: Source line count ... [PASS] PASSED

========================================
Bug Fix Validation (9 Critical Fixes)
========================================
--- Fix 1: vlog() function with return 0 ---
  Testing: vlog() has return 0 ... [PASS] PASSED
[... continues for all 9 fixes ...]

[... 40+ more tests ...]

================================================================================
kali-sweep Comprehensive Test Report
================================================================================
Test Statistics:
----------------
Total Tests:    52
Passed:         50
Failed:         0
Skipped:        2
Success Rate:   96%

✓ ALL TESTS PASSED

System Status: PRODUCTION READY
```

**If source is NOT synced:**
```
========================================
Source Code Sync Validation
========================================
  Testing: Source and binary match (SHA256) ... [FAIL] FAILED - Hashes differ
  ⚠ CRITICAL: Run sync command first:
    cd ~/field-scripts/kali-sweep
    sudo cp /usr/sbin/kali-sweep kali_sweep_v3_2_1.sh
    sudo chown $USER:$USER kali_sweep_v3_2_1.sh
```

### Reviewing Results

```bash
# View summary
cat test-results-*/test-report.txt

# View full log
less test-YYYYMMDD_HHMMSS.log

# Search for failures
grep FAIL test-*.log

# Check specific test category
grep "Bug Fix Validation" test-*.log -A 30
```

---

## 📊 Part 2: File Audit

### What It Does

Analyzes complete file structure:
- All installed system files
- All development directory files
- Compares dev vs installed (with diffs)
- Disk usage breakdown
- **Specific cleanup recommendations for YOUR files**
- Complete file manifest

### How to Run

```bash
cd ~/field-scripts/kali-sweep

# Make executable
chmod +x audit-files.sh

# Quick audit (screen output)
./audit-files.sh

# Save to file for review
./audit-files.sh --output audit-report.txt

# Include file content (verbose)
./audit-files.sh --include-content --output full-audit.txt
```

### Output Structure

```
===============================================================================
INSTALLED SYSTEM FILES
===============================================================================
---- Package Information ----
ii  kali-sweep  3.2.1-1  all  Hostile housekeeping for Kali

---- Main Binary ----
File: /usr/sbin/kali-sweep
Size: 33049 bytes (32KB)
Line count: 886
SHA256: 44e0d4a3af88180af06d618e68e97b27c37880c50225440de24f9d1723d69b60

===============================================================================
DEVELOPMENT vs INSTALLED COMPARISON
===============================================================================
--- Main Script ---
Development: kali_sweep_v3_2_1.sh
  SHA256: 3e173524ccbfeac3270ff4d2fbe1706a2c6ed7ba4f76462d5cb2f15b63462592
Installed: /usr/sbin/kali-sweep
  SHA256: 44e0d4a3af88180af06d618e68e97b27c37880c50225440de24f9d1723d69b60

Status: ✗ DIFFERENT (out of sync!)
Action Required: [sync commands shown]

===============================================================================
CLEANUP RECOMMENDATIONS
===============================================================================
✓ ESSENTIAL FILES (Keep These)
  ✓ kali_sweep_v3_2_1.sh
  ✓ prepare_package.sh
  [... etc ...]

⚠ REVIEW THESE FILES
  ⚠ staging/ directory (150KB)
     Can delete: Yes (regenerated on build)
     Action: rm -rf staging

  ⚠ backup/ directory (71KB)
     Can delete: If you don't need old versions
     Action: Review contents first

  ⚠ build_deb.sh
     Note: prepare_package.sh is recommended
     Can delete: Yes
     Action: rm build_deb.sh

  [... specific to YOUR files ...]
```

### Using the Audit Results

1. **Review the report:**
   ```bash
   less audit-report.txt
   ```

2. **Check sync status:**
   ```bash
   grep "Status:" audit-report.txt
   ```

3. **Find cleanup opportunities:**
   ```bash
   grep -A 5 "REVIEW THESE" audit-report.txt
   ```

4. **Execute recommended cleanups:**
   ```bash
   # Example based on recommendations
   rm -rf ~/field-scripts/kali-sweep/staging
   rm ~/field-scripts/kali-sweep/build_deb.sh
   ```

---

## 🎯 Recommended Workflow

### First Time (Complete Validation)

```bash
cd ~/field-scripts/kali-sweep

# Step 1: SYNC SOURCE (CRITICAL!)
sudo cp /usr/sbin/kali-sweep kali_sweep_v3_2_1.sh
sudo chown $USER:$USER kali_sweep_v3_2_1.sh

# Step 2: Run comprehensive tests
sudo ./comprehensive-test.sh --keep-logs

# Step 3: Review results
cat test-results-*/test-report.txt

# Step 4: If all pass, run audit
./audit-files.sh --output audit-report.txt

# Step 5: Review audit
less audit-report.txt

# Step 6: Clean up based on recommendations
# (carefully execute recommended rm commands)

# Step 7: Final verification
sudo ./verify_install.sh
```

### Quick Check (After Changes)

```bash
cd ~/field-scripts/kali-sweep

# Quick test run
sudo ./comprehensive-test.sh

# If tests pass, you're good!
```

### Periodic Maintenance

```bash
# Monthly: Check for old logs
./audit-files.sh | grep "old reports"

# After changes: Quick validation
sudo ./comprehensive-test.sh

# Before release: Full validation
sudo ./comprehensive-test.sh --keep-logs
./audit-files.sh --output audit-$(date +%Y%m%d).txt
```

---

## 🐛 Troubleshooting

### "Source and binary match" test FAILS

**Solution:** Sync your source code (see CRITICAL section above)

### "Package not installed" errors

**Solution:**
```bash
cd ~/field-scripts/kali-sweep
sudo dpkg -i staging/kali-sweep_3.2.1-1.deb
```

### "Permission denied" errors

**Solution:** Run with sudo:
```bash
sudo ./comprehensive-test.sh
```

### Tests hang or timeout

**Solution:** Check if another sweep is running:
```bash
sudo systemctl stop kali-sweep.timer
sudo systemctl stop kali-sweep.service
# Then retry tests
```

### "Timer not active" warnings

**Expected:** If you prefer manual operation. Otherwise:
```bash
sudo systemctl start kali-sweep.timer
```

---

## 📈 Understanding Test Results

### Success Rate

- **100%** = Perfect (rare, some skips expected)
- **95-99%** = Excellent (normal with skips)
- **90-94%** = Good (investigate failures)
- **<90%** = Issues need attention

### Common Skips (Normal)

These are expected and OK:
- "Timer not enabled" - Manual operation is fine
- "Timer not active" - If you haven't started it
- "jq not installed" - JSON validation tool
- "Integer validation nested" - Complex to detect automatically

### Critical Failures (Fix These)

- "Source and binary match" - MUST sync
- "vlog() has return 0" - Bug fix missing
- "Summary uses command grouping" - Bug fix missing
- "Package installed" - Installation problem
- "Sweep executes successfully" - Major issue

---

## 📊 What the Numbers Mean

### From Test Output

```
Test Statistics:
Total Tests:    52     ← All tests executed
Passed:         50     ← Tests that passed
Failed:         0      ← Tests that failed (should be 0!)
Skipped:        2      ← Tests skipped (optional features)
Success Rate:   96%    ← (Passed / Total) * 100
```

**Target:** 0 failures, 95%+ success rate

### From Audit Output

```
✓ Shell scripts: 7
✓ Documentation files: 8
⚠ staging/ directory present
```

Shows what you have and what can be cleaned up.

---

## 🎓 Advanced Usage

### Test Only Specific Categories

Edit `comprehensive-test.sh` and comment out categories you don't need:

```bash
# main() {
    # ...
    # validate_source_sync
    # validate_bug_fixes
    # installation_tests
    # dryrun_tests
    sweep_tests  # Only run this one
    # baseline_tests
    # ...
# }
```

### Save Test History

```bash
# Create a test history directory
mkdir -p ~/kali-sweep-test-history

# Run tests and save
sudo ./comprehensive-test.sh --keep-logs
cp test-results-*/* ~/kali-sweep-test-history/

# Compare over time
diff ~/kali-sweep-test-history/test-report-*.txt
```

### Automated Testing

```bash
# Add to cron for weekly validation
sudo crontab -e

# Add this line (runs Sundays at 2 AM):
0 2 * * 0 cd ~/field-scripts/kali-sweep && ./comprehensive-test.sh > /var/log/kali-sweep-tests.log 2>&1
```

---

## ✅ Success Checklist

After running both scripts, you should have:

- [✓] Source code synced (hashes match)
- [✓] All 9 bug fixes validated
- [✓] 50+ tests passing
- [✓] Success rate 95%+
- [✓] Complete file inventory
- [✓] Cleanup recommendations reviewed
- [✓] Unnecessary files removed
- [✓] Test results documented

**If all checked:** Your kali-sweep installation is production-ready! 🎉

---

## 📞 Next Steps

### After Tests Pass

1. **Create system baseline:**
   ```bash
   sudo kali-sweep --baseline /root/kali-baseline --paranoid
   ```

2. **Configure for your environment:**
   ```bash
   sudo nano /etc/kali-sweep.conf
   # Add your common ports
   ```

3. **Start automatic sweeps:**
   ```bash
   sudo systemctl start kali-sweep.timer
   ```

4. **Create final archive:**
   ```bash
   tar czf kali-sweep-production-$(date +%Y%m%d).tar.gz \
     kali_sweep_v3_2_1.sh \
     prepare_package.sh \
     verify_install.sh \
     comprehensive-test.sh \
     audit-files.sh \
     *.md
   ```

### If Tests Fail

1. Review test-results-*/test-report.txt
2. Check the detailed log
3. Fix the specific issue
4. Rerun tests
5. Repeat until clean

---

## 🆘 Getting Help

### Check These First

1. Did you sync source code?
2. Is package installed?
3. Are you running with sudo?
4. Is another sweep running?

### Logs to Check

```bash
# Test logs
less test-*.log

# Sweep logs
sudo journalctl -u kali-sweep.service -n 100

# System errors
sudo journalctl -p err -n 50
```

### Diagnostic Tool

The other LLM created a diagnostic script:
```bash
sudo ./onboard_debug_kali_sweep.sh
```

This captures system state for debugging.

---

## 📚 Additional Documentation

- **QUICKREF.md** - Quick command reference
- **RUNBOOK.md** - Incident response guide
- **README.md** - User guide
- **DEPLOYMENT.md** - Ops guide
- **PROJECT_SUMMARY.md** - Complete overview

---

**You're all set! Run the tests and let's see how it goes!** 🚀
