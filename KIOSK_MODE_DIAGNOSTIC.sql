-- Kiosk Mode Diagnostic Script
-- Run this to diagnose why kiosk mode is not working on your device
-- Replace <config_id> with your configuration ID (usually 1)

-- Step 1: Check configuration settings
SELECT 
    id,
    name,
    kioskMode,
    contentAppId,
    mainAppId
FROM configurations 
WHERE id = 1;  -- Replace with your configuration ID

-- Step 2: Check if contentAppId points to a valid ApplicationVersion
-- If this returns no rows, the ApplicationVersion is missing!
SELECT 
    av.id as version_id,
    av.applicationId,
    av.version,
    av.url
FROM applicationVersions av
WHERE av.id = (SELECT contentAppId FROM configurations WHERE id = 1);

-- Step 3: Check if the Application exists
-- This should return the application details
SELECT 
    a.id,
    a.name,
    a.pkg,
    a.latestVersion
FROM applications a
WHERE a.id = (
    SELECT av.applicationId 
    FROM applicationVersions av
    WHERE av.id = (SELECT contentAppId FROM configurations WHERE id = 1)
);

-- Step 4: Check for database inconsistency
-- Find applications where latestVersion points to non-existent ApplicationVersion
SELECT 
    a.id,
    a.name,
    a.pkg,
    a.latestVersion as points_to_version,
    CASE 
        WHEN av.id IS NULL THEN 'MISSING - This is a problem!'
        ELSE 'EXISTS'
    END as version_status
FROM applications a
LEFT JOIN applicationVersions av ON a.latestVersion = av.id
WHERE a.latestVersion IS NOT NULL
ORDER BY version_status, a.id;

-- Step 5: Find all versions for the content app
-- Replace 78 with your application ID from Step 3
SELECT 
    av.id,
    av.version,
    av.url,
    av.versionCode
FROM applicationVersions av
WHERE av.applicationId = 78  -- Replace with your application ID
ORDER BY av.id DESC;

-- Step 6: If you need to fix contentAppId to point to an existing version
-- Uncomment and run after replacing the IDs:
-- UPDATE configurations 
-- SET contentAppId = <existing_version_id>  -- Use ID from Step 5
-- WHERE id = 1;  -- Your configuration ID

-- Step 7: Verify the fix
-- Run this after updating contentAppId
-- All three queries should return results
SELECT 'Configuration' as table_name, COUNT(*) as count FROM configurations WHERE id = 1 AND contentAppId IS NOT NULL
UNION ALL
SELECT 'ApplicationVersion', COUNT(*) FROM applicationVersions WHERE id = (SELECT contentAppId FROM configurations WHERE id = 1)
UNION ALL
SELECT 'Application', COUNT(*) FROM applications WHERE id = (SELECT applicationId FROM applicationVersions WHERE id = (SELECT contentAppId FROM configurations WHERE id = 1));
