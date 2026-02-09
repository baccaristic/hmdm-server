# Kiosk Mode Troubleshooting Guide

## Your Issue: Device Shows "Kiosk Mode: no"

Based on your report, the device is showing:
- Launcher variant: opensource
- **Kiosk mode: no** (should be yes)
- Default launcher: com.hmdm.launcher

## Root Cause

Your configuration likely has:
- `kioskMode = true` in the database
- `contentAppId = <some_version_id>` (e.g., 10077)
- Application exists in database (e.g., ID 78 with package "your.app.package")

However, the device is receiving `kioskMode = false` from the server. This means my validation code detected a problem and disabled kiosk mode to prevent device-side failures.

**Most Likely Issue:** The `applicationVersions` table does not have a record with the ID specified in `contentAppId`, even though your `applications.latestVersion` field may show the same ID. This is a database inconsistency.

## How to Diagnose

### Step 1: Check Server Logs

When your device syncs, check the server logs:

```bash
# Look for warnings about kiosk mode
tail -f /path/to/tomcat/logs/catalina.out | grep "Kiosk mode"
```

You should see one of these warnings:
- ❌ "Kiosk mode is enabled for configuration X but content app version with ID Y does not exist"
- ✅ "Kiosk mode enabled for configuration X with content app: your.app.package (Z)"

If you see the ❌ warning, continue to Step 2.

### Step 2: Run Diagnostic SQL

Run the diagnostic script I created:

```bash
cd <your_hmdm_server_directory>
psql -U hmdm -d hmdm -f KIOSK_MODE_DIAGNOSTIC.sql
```

Or run these queries manually:

```sql
-- Check if ApplicationVersion exists (replace with your contentAppId)
SELECT * FROM applicationVersions WHERE id = <your_contentAppId>;
```

**If this returns no rows, that's your problem!**

## How to Fix

### Option A: Re-upload the APK (Recommended)

This is the easiest and safest method:

1. Go to the web UI
2. Navigate to **Applications**
3. Find your content application (the one configured for kiosk mode)
4. Click to edit/view it
5. Upload the APK file again
6. This will create a new ApplicationVersion record
7. The system will update the configuration automatically

### Option B: Use Existing Version

If other versions of the app exist:

```sql
-- Find existing versions (replace with your application ID)
SELECT id, version, url FROM applicationVersions WHERE applicationId = <your_application_id> ORDER BY id DESC;

-- Update configuration to use an existing version
-- Replace <version_id> with an id from the query above
-- Replace <config_id> with your configuration ID (usually 1)
UPDATE configurations SET contentAppId = <version_id> WHERE id = <config_id>;
```

### Option C: Manual Fix (Advanced)

Only if you understand the database structure:

```sql
-- Create a new ApplicationVersion record
-- Replace values with your actual application details
INSERT INTO applicationVersions (applicationId, version, url, versionCode)
VALUES (<your_application_id>, '1.0', '/path/to/your_app.apk', 1);

-- Get the new version ID
SELECT id FROM applicationVersions WHERE applicationId = <your_application_id> ORDER BY id DESC LIMIT 1;

-- Update configuration to use new version
UPDATE configurations SET contentAppId = <new_id> WHERE id = <config_id>;

-- Update application's latestVersion pointer
UPDATE applications SET latestVersion = <new_id> WHERE id = <your_application_id>;
```

## Verify the Fix

After applying one of the fixes above:

1. Sync the device again
2. Check server logs for: ✅ "Kiosk mode enabled for configuration X with content app: your.app.package (Y)"
3. Check device info - should now show: **Kiosk mode: yes**

## Quick Reference SQL Queries

```sql
-- Check current configuration (replace with your config ID)
SELECT id, name, kioskMode, contentAppId FROM configurations WHERE id = <config_id>;

-- Verify ApplicationVersion exists (replace with your contentAppId)
SELECT * FROM applicationVersions WHERE id = <your_contentAppId>;

-- Check Application details (replace with your application ID)
SELECT id, name, pkg, latestVersion FROM applications WHERE id = <your_application_id>;

-- Find all versions for this app (replace with your application ID)
SELECT id, version, url FROM applicationVersions WHERE applicationId = <your_application_id> ORDER BY id DESC;

-- Check for database inconsistencies (replace with your application ID)
SELECT a.id, a.name, a.latestVersion, 
       CASE WHEN av.id IS NULL THEN 'MISSING!' ELSE 'OK' END as status
FROM applications a
LEFT JOIN applicationVersions av ON a.latestVersion = av.id
WHERE a.id = <your_application_id>;
```

## Need More Help?

If the above steps don't resolve the issue, provide:
1. Output of the diagnostic SQL script
2. Server log excerpts showing kiosk mode warnings
3. Results of the verification queries

The detailed logging I added will pinpoint exactly which validation step is failing.

## Important: Kiosk Mode Security

### Automatic Security Enforcement

When kiosk mode is enabled with a valid content app, the server **automatically enforces security restrictions**:

1. **Permissive mode is forced to false**
   - Even if permissive mode was enabled in configuration
   - This ensures all kiosk restrictions are applied
   - Users cannot access device settings or bypass restrictions

2. **Server Log Message**
   ```
   INFO: Kiosk mode is enabled for configuration X - forcing permissive mode to false to enforce restrictions
   ```
   This is normal and indicates proper security enforcement.

3. **Why This Matters**
   - `kioskMode=true` + `permissive=true` would allow users to access settings (SECURITY RISK)
   - `kioskMode=true` + `permissive=false` properly locks down the device (SECURE)
   - Server automatically ensures the secure configuration

### Settings in Configuration UI

In the web UI, when kiosk mode is enabled:
- The "Permissive mode" checkbox is disabled (grayed out)
- Its value doesn't matter - server forces it to false anyway
- This prevents administrators from accidentally creating an insecure configuration

### What Gets Restricted in Kiosk Mode

With kiosk mode enabled and permissive=false (automatic):
- Users cannot access Android settings
- Users cannot install/uninstall apps
- Users cannot change system configuration
- Only the configured content app can run
- Home button and recents can be optionally disabled
