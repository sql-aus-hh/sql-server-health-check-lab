/*
    SQL Server Health Check Lab
    Scenario 01 - Build / Setup Review
    Validate.sql

    Run this script AFTER restarting the SQL Server service.
*/

SET NOCOUNT ON;

DECLARE @Results table
(
    CheckName nvarchar(200),
    ExpectedValue nvarchar(4000),
    ActualValue nvarchar(4000),
    Result varchar(10)
);

-------------------------------------------------------------------------------
-- Instance configuration
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'max server memory (MB)',
    N'2147483647',
    CONVERT(nvarchar(100), value_in_use),
    CASE WHEN value_in_use = 2147483647 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'max server memory (MB)';

INSERT @Results
SELECT N'MAXDOP', N'0', CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'max degree of parallelism';

INSERT @Results
SELECT N'Cost Threshold for Parallelism', N'5',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 5 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'cost threshold for parallelism';

INSERT @Results
SELECT N'Backup Compression Default', N'0',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'backup compression default';

INSERT @Results
SELECT N'Optimize for Ad Hoc Workloads', N'0',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'optimize for ad hoc workloads';

-------------------------------------------------------------------------------
-- WorkshopLab database options
-------------------------------------------------------------------------------
INSERT @Results
SELECT N'WorkshopLab AUTO_SHRINK', N'ON',
       CASE WHEN is_auto_shrink_on = 1 THEN N'ON' ELSE N'OFF' END,
       CASE WHEN is_auto_shrink_on = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab AUTO_CLOSE', N'OFF',
       CASE WHEN is_auto_close_on = 1 THEN N'ON' ELSE N'OFF' END,
       CASE WHEN is_auto_close_on = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab PAGE_VERIFY', N'CHECKSUM',
       page_verify_option_desc,
       CASE WHEN page_verify_option_desc = N'CHECKSUM' THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab Recovery Model', N'FULL',
       recovery_model_desc,
       CASE WHEN recovery_model_desc = N'FULL' THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

-------------------------------------------------------------------------------
-- WorkshopLab file growth
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'WorkshopLab file growth - ' + name,
    N'1 MB',
    CASE
        WHEN is_percent_growth = 1 THEN CONVERT(nvarchar(50), growth) + N'%'
        ELSE CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB'
    END,
    CASE
        WHEN is_percent_growth = 0 AND growth = 128 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM sys.master_files
WHERE database_id = DB_ID(N'WorkshopLab');

-------------------------------------------------------------------------------
-- Backup history
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'WorkshopLab backup history',
    N'No backup history',
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM msdb.dbo.backupset
        WHERE database_name = N'WorkshopLab'
    )
    THEN N'Backup history exists'
    ELSE N'No backup history'
    END,
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM msdb.dbo.backupset
        WHERE database_name = N'WorkshopLab'
    )
    THEN 'FAIL' ELSE 'PASS' END;

-------------------------------------------------------------------------------
-- Default paths
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Default Data Path',
    N'C:\...',
    COALESCE(CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultDataPath')), N'<NULL>'),
    CASE WHEN CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultDataPath')) LIKE N'C:\%'
         THEN 'PASS' ELSE 'FAIL' END;

INSERT @Results
SELECT
    N'Default Log Path',
    N'C:\...',
    COALESCE(CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultLogPath')), N'<NULL>'),
    CASE WHEN CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultLogPath')) LIKE N'C:\%'
         THEN 'PASS' ELSE 'FAIL' END;

-------------------------------------------------------------------------------
-- TempDB
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'TempDB file count',
    N'3',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB size - ' + name,
    N'8 MB',
    CONVERT(nvarchar(50), size * 8 / 1024) + N' MB',
    CASE WHEN size = 1024 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB path - ' + name,
    N'C:\...',
    physical_name,
    CASE WHEN physical_name LIKE N'C:\%' THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB growth - ' + name,
    N'1 MB',
    CASE
        WHEN is_percent_growth = 1 THEN CONVERT(nvarchar(50), growth) + N'%'
        ELSE CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB'
    END,
    CASE
        WHEN is_percent_growth = 0 AND growth = 128 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM tempdb.sys.database_files;

-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------
SELECT CheckName, ExpectedValue, ActualValue, Result
FROM @Results
ORDER BY CASE WHEN Result = 'FAIL' THEN 0 ELSE 1 END, CheckName;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = 'FAIL')
BEGIN
    PRINT '';
    PRINT 'Scenario 01 validation FAILED. Review the rows above.';
END
ELSE
BEGIN
    PRINT '';
    PRINT 'Scenario 01 validation PASSED.';
END
