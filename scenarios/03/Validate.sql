/*
    SQL Server Health Check Lab
    Scenario 03 - Health Check / Assess, Don't Assume
    Validate.sql

    Purpose:
      Verify that the intended mixed Health Check state exists.

    IMPORTANT:
      PASS means the lab scenario was reproduced as intended.
      PASS does NOT mean the setting itself is healthy.
*/

USE [master];
GO

SET NOCOUNT ON;

DECLARE @Results table
(
    CheckName nvarchar(260) NOT NULL,
    ExpectedValue nvarchar(4000) NULL,
    ActualValue nvarchar(4000) NULL,
    Result varchar(10) NOT NULL
);

DECLARE
    @BackupJob sysname = N'SQLDays - Slot3 - Daily Full Backup',
    @CheckDbJob sysname = N'SQLDays - Slot3 - Weekly CHECKDB',
    @MaintenanceJob sysname = N'SQLDays - Slot3 - Nightly Maintenance',
    @OperatorName sysname = N'SQLDays - Slot3 - DBA Operator';

-------------------------------------------------------------------------------
-- 1. Instance configuration
-------------------------------------------------------------------------------
INSERT @Results
SELECT N'max server memory (MB)', N'6144',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 6144 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'max server memory (MB)';

INSERT @Results
SELECT N'MAXDOP', N'0',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'max degree of parallelism';

INSERT @Results
SELECT N'Cost Threshold for Parallelism', N'50',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 50 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'cost threshold for parallelism';

INSERT @Results
SELECT N'Backup Compression Default', N'1',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'backup compression default';

-------------------------------------------------------------------------------
-- 2. TempDB
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'TempDB growth - tempdev',
    N'256 MB',
    CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB',
    CASE WHEN is_percent_growth = 0 AND growth = 32768 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files
WHERE name = N'tempdev';

INSERT @Results
SELECT
    N'TempDB growth - tempdev2',
    N'64 MB',
    CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB',
    CASE WHEN is_percent_growth = 0 AND growth = 8192 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files
WHERE name = N'tempdev2';

INSERT @Results
SELECT
    N'TempDB growth - templog',
    N'256 MB',
    CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB',
    CASE WHEN is_percent_growth = 0 AND growth = 32768 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files
WHERE name = N'templog';

-------------------------------------------------------------------------------
-- 3. HealthCheckApp
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'HealthCheckApp state',
    N'ONLINE',
    COALESCE(state_desc, N'<missing>'),
    CASE WHEN state_desc = N'ONLINE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'HealthCheckApp';

INSERT @Results
SELECT
    N'HealthCheckApp recovery model',
    N'FULL',
    COALESCE(recovery_model_desc, N'<missing>'),
    CASE WHEN recovery_model_desc = N'FULL' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'HealthCheckApp';

INSERT @Results
SELECT
    N'HealthCheckApp compatibility level',
    N'150',
    COALESCE(CONVERT(nvarchar(50), compatibility_level), N'<missing>'),
    CASE WHEN compatibility_level = 150 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'HealthCheckApp';

INSERT @Results
SELECT
    N'HealthCheckApp PAGE_VERIFY',
    N'CHECKSUM',
    COALESCE(page_verify_option_desc, N'<missing>'),
    CASE WHEN page_verify_option_desc = N'CHECKSUM' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'HealthCheckApp';

INSERT @Results
SELECT
    N'HealthCheckApp AUTO_SHRINK',
    N'OFF',
    CASE
        WHEN d.name IS NULL THEN N'<missing>'
        WHEN is_auto_shrink_on = 1 THEN N'ON'
        ELSE N'OFF'
    END,
    CASE WHEN d.name IS NOT NULL AND is_auto_shrink_on = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'HealthCheckApp';

INSERT @Results
SELECT
    N'HealthCheckApp Query Store',
    N'OFF',
    CASE
        WHEN d.name IS NULL THEN N'<missing>'
        WHEN is_query_store_on = 1 THEN N'ON'
        ELSE N'OFF'
    END,
    CASE WHEN d.name IS NOT NULL AND is_query_store_on = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'HealthCheckApp';

INSERT @Results
SELECT
    N'HealthCheckApp data file count',
    N'2',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'HealthCheckApp')
  AND type = 0;

INSERT @Results
SELECT
    N'HealthCheckApp archive file on system drive',
    N'C:\...',
    COALESCE(MAX(CASE WHEN name = N'HealthCheckApp_Archive' THEN physical_name END), N'<missing>'),
    CASE WHEN MAX(CASE WHEN name = N'HealthCheckApp_Archive' THEN physical_name END) LIKE N'C:\%'
         THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'HealthCheckApp');

-------------------------------------------------------------------------------
-- 4. Backup situation
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'HealthCheckApp Full backups',
    N'2',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'HealthCheckApp'
  AND type = 'D';

INSERT @Results
SELECT
    N'HealthCheckApp Log backups',
    N'0',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'HealthCheckApp'
  AND type = 'L';

INSERT @Results
SELECT
    N'HealthCheckApp local restore history',
    N'0',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.restorehistory
WHERE destination_database_name = N'HealthCheckApp';

DECLARE @FileCheck table
(
    FileExists int,
    IsDirectory int,
    ParentDirectoryExists int
);

INSERT @FileCheck
EXEC master.dbo.xp_fileexist N'G:\SQLBackup\Slot3\HealthCheckApp_FULL.bak';

INSERT @Results
SELECT
    N'HealthCheckApp Full backup file',
    N'EXISTS',
    CASE WHEN MAX(FileExists) = 1 THEN N'EXISTS' ELSE N'MISSING' END,
    CASE WHEN MAX(FileExists) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM @FileCheck;

BEGIN TRY
    RESTORE VERIFYONLY
    FROM DISK = N'G:\SQLBackup\Slot3\HealthCheckApp_FULL.bak'
    WITH CHECKSUM;

    INSERT @Results
    VALUES
    (
        N'HealthCheckApp Full backup VERIFYONLY',
        N'VALID',
        N'VALID',
        'PASS'
    );
END TRY
BEGIN CATCH
    INSERT @Results
    VALUES
    (
        N'HealthCheckApp Full backup VERIFYONLY',
        N'VALID',
        ERROR_MESSAGE(),
        'FAIL'
    );
END CATCH;

-------------------------------------------------------------------------------
-- 5. LegacyReporting
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'LegacyReporting state',
    N'ONLINE',
    COALESCE(state_desc, N'<missing>'),
    CASE WHEN state_desc = N'ONLINE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'LegacyReporting';

INSERT @Results
SELECT
    N'LegacyReporting recovery model',
    N'SIMPLE',
    COALESCE(recovery_model_desc, N'<missing>'),
    CASE WHEN recovery_model_desc = N'SIMPLE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'LegacyReporting';

INSERT @Results
SELECT
    N'LegacyReporting AUTO_SHRINK',
    N'ON',
    CASE
        WHEN d.name IS NULL THEN N'<missing>'
        WHEN is_auto_shrink_on = 1 THEN N'ON'
        ELSE N'OFF'
    END,
    CASE WHEN d.name IS NOT NULL AND is_auto_shrink_on = 1 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'LegacyReporting';

INSERT @Results
SELECT
    N'LegacyReporting PAGE_VERIFY',
    N'TORN_PAGE_DETECTION',
    COALESCE(page_verify_option_desc, N'<missing>'),
    CASE WHEN page_verify_option_desc = N'TORN_PAGE_DETECTION' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'LegacyReporting';

INSERT @Results
SELECT
    N'LegacyReporting TRUSTWORTHY',
    N'ON',
    CASE
        WHEN d.name IS NULL THEN N'<missing>'
        WHEN is_trustworthy_on = 1 THEN N'ON'
        ELSE N'OFF'
    END,
    CASE WHEN d.name IS NOT NULL AND is_trustworthy_on = 1 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'LegacyReporting';

INSERT @Results
SELECT
    N'LegacyReporting percent growth files',
    N'2',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'LegacyReporting')
  AND is_percent_growth = 1
  AND growth = 10;

INSERT @Results
SELECT
    N'LegacyReporting backup history',
    N'0',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'LegacyReporting';

-------------------------------------------------------------------------------
-- 6. SQL Agent
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Daily Full Backup job enabled',
    N'YES',
    CASE WHEN j.enabled = 1 THEN N'YES' ELSE N'NO / MISSING' END,
    CASE WHEN j.enabled = 1 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysjobs j ON j.name = @BackupJob;

INSERT @Results
SELECT
    N'Daily Full Backup job last outcome',
    N'SUCCEEDED',
    CASE h.run_status
        WHEN 0 THEN N'FAILED'
        WHEN 1 THEN N'SUCCEEDED'
        WHEN 2 THEN N'RETRY'
        WHEN 3 THEN N'CANCELED'
        WHEN 4 THEN N'IN PROGRESS'
        ELSE N'<no history>'
    END,
    CASE WHEN h.run_status = 1 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysjobs j ON j.name = @BackupJob
OUTER APPLY
(
    SELECT TOP (1) h2.run_status
    FROM msdb.dbo.sysjobhistory h2
    WHERE h2.job_id = j.job_id
      AND h2.step_id = 0
    ORDER BY h2.instance_id DESC
) h;

INSERT @Results
SELECT
    N'Weekly CHECKDB job enabled',
    N'NO',
    CASE
        WHEN j.job_id IS NULL THEN N'<missing>'
        WHEN j.enabled = 1 THEN N'YES'
        ELSE N'NO'
    END,
    CASE WHEN j.job_id IS NOT NULL AND j.enabled = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysjobs j ON j.name = @CheckDbJob;

INSERT @Results
SELECT
    N'Nightly Maintenance contains SHRINKDATABASE',
    N'YES',
    CASE WHEN MAX(CASE WHEN s.command LIKE N'%SHRINKDATABASE%' THEN 1 ELSE 0 END) = 1
         THEN N'YES' ELSE N'NO' END,
    CASE WHEN MAX(CASE WHEN s.command LIKE N'%SHRINKDATABASE%' THEN 1 ELSE 0 END) = 1
         THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobsteps s ON s.job_id = j.job_id
WHERE j.name = @MaintenanceJob;

-------------------------------------------------------------------------------
-- 7. Operator
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Operator email',
    N'healthcheck@example.invalid',
    COALESCE(o.email_address, N'<missing>'),
    CASE WHEN o.email_address = N'healthcheck@example.invalid' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysoperators o
    ON o.name = @OperatorName;

-------------------------------------------------------------------------------
-- 8. Output
-------------------------------------------------------------------------------
SELECT
    CheckName,
    ExpectedValue,
    ActualValue,
    Result
FROM @Results
ORDER BY
    CASE WHEN Result = 'FAIL' THEN 0 ELSE 1 END,
    CheckName;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = 'FAIL')
BEGIN
    PRINT '';
    PRINT 'Scenario 03 validation FAILED.';
    PRINT 'Resolve failed preparation checks before starting the exercise.';
END
ELSE
BEGIN
    PRINT '';
    PRINT 'Scenario 03 validation PASSED.';
    PRINT 'The mixed Health Check environment is ready.';
END;
