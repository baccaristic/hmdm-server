# Kiosk Mode Troubleshooting Guide

## Your Issue: Device Shows "Kiosk Mode: no"

Based on your report, the device is showing:
- Launcher variant: opensource
- **Kiosk mode: no** (should be yes)
- Default launcher: com.hmdm.launcher

## Root Cause

Your configuration has:
- `kioskMode = true` in the database
- `contentAppId = 10077`
- Application ID 78 exists with package "tn.foodify.foodifyrestaurant"

However, the device is receiving `kioskMode = false` from the server. This means my validation code detected a problem and disabled kiosk mode to prevent device-side failures.

**Most Likely Issue:** The `applicationVersions` table does not have a record with `id = 10077`, even though your `applications.latestVersion` field shows 10077. This is a database inconsistency.

## How to Diagnose

### Step 1: Check Server Logs

When your device syncs, check the server logs:

```bash
# Look for warnings about kiosk mode
tail -f /path/to/tomcat/logs/catalina.out | grep "Kiosk mode"
```

You should see one of these warnings:
- ❌ "Kiosk mode is enabled for configuration 1 but content app version with ID 10077 does not exist"
- ✅ "Kiosk mode enabled for configuration 1 with content app: tn.foodify.foodifyrestaurant (78)"

If you see the ❌ warning, continue to Step 2.

### Step 2: Run Diagnostic SQL

Run the diagnostic script I created:

```bash
cd /home/runner/work/hmdm-server/hmdm-server
psql -U hmdm -d hmdm -f KIOSK_MODE_DIAGNOSTIC.sql
```

Or run these queries manually:

```sql
-- Check if ApplicationVersion exists
SELECT * FROM applicationVersions WHERE id = 10077;
```

**If this returns no rows, that's your problem!**

## How to Fix

### Option A: Re-upload the APK (Recommended)

This is the easiest and safest method:

1. Go to the web UI
2. Navigate to **Applications**
3. Find "Foodify Restaurant" application
4. Click to edit/view it
5. Upload the APK file again
6. This will create a new ApplicationVersion record
7. The system will update the configuration automatically

### Option B: Use Existing Version

If other versions of the app exist:

```sql
-- Find existing versions
SELECT id, version, url FROM applicationVersions WHERE applicationId = 78 ORDER BY id DESC;

-- Update configuration to use an existing version
-- Replace <version_id> with an id from the query above
UPDATE configurations SET contentAppId = <version_id> WHERE id = 1;
```

### Option C: Manual Fix (Advanced)

Only if you understand the database structure:

```sql
-- Create a new ApplicationVersion record
INSERT INTO applicationVersions (applicationId, version, url, versionCode)
VALUES (78, '1.0', '/path/to/foodify.apk', 1);

-- Get the new version ID
SELECT id FROM applicationVersions WHERE applicationId = 78 ORDER BY id DESC LIMIT 1;

-- Update configuration to use new version
UPDATE configurations SET contentAppId = <new_id> WHERE id = 1;

-- Update application's latestVersion pointer
UPDATE applications SET latestVersion = <new_id> WHERE id = 78;
```

## Verify the Fix

After applying one of the fixes above:

1. Sync the device again
2. Check server logs for: ✅ "Kiosk mode enabled for configuration 1 with content app: tn.foodify.foodifyrestaurant (78)"
3. Check device info - should now show: **Kiosk mode: yes**

## Quick Reference SQL Queries

```sql
-- Check current configuration
SELECT id, name, kioskMode, contentAppId FROM configurations WHERE id = 1;

-- Verify ApplicationVersion exists
SELECT * FROM applicationVersions WHERE id = 10077;

-- Check Application details
SELECT id, name, pkg, latestVersion FROM applications WHERE id = 78;

-- Find all versions for this app
SELECT id, version, url FROM applicationVersions WHERE applicationId = 78 ORDER BY id DESC;

-- Check for database inconsistencies
SELECT a.id, a.name, a.latestVersion, 
       CASE WHEN av.id IS NULL THEN 'MISSING!' ELSE 'OK' END as status
FROM applications a
LEFT JOIN applicationVersions av ON a.latestVersion = av.id
WHERE a.id = 78;
```

## Need More Help?

If the above steps don't resolve the issue, provide:
1. Output of the diagnostic SQL script
2. Server log excerpts showing kiosk mode warnings
3. Results of the verification queries

The detailed logging I added will pinpoint exactly which validation step is failing.
