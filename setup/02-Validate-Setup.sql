/*
    SQL Server Health Check Lab
    Common Setup
    02-Validate-Setup.sql

    Run AFTER the SQL Server service restart.
*/

USE [master];
GO

SET NOCOUNT ON;

DECLARE @Results table
(
    CheckName nvarchar(200) NOT NULL,
    ExpectedValue nvarchar(4000) NULL,
    ActualValue nvarchar(4000) NULL,
    Result varchar(10) NOT NULL
);

-------------------------------------------------------------------------------
-- 1. Instance / version
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Edition',
    N'Developer Edition',
    CONVERT(nvarchar(4000), SERVERPROPERTY('Edition')),
    CASE
        WHEN CONVERT(nvarchar(4000), SERVERPROPERTY('Edition')) LIKE N'%Developer%'
        THEN 'PASS' ELSE 'FAIL'
    END;

-------------------------------------------------------------------------------
-- 2. Lab VM resources
--
-- These are informational. A different VM size can still be used, but the
-- workshop baseline values were chosen for 2 vCPU / 8 GiB RAM.
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Lab VM CPU count',
    N'2 vCPU (recommended)',
    CONVERT(nvarchar(100), cpu_count),
    CASE WHEN cpu_count = 2 THEN 'PASS' ELSE 'INFO' END
FROM sys.dm_os_sys_info;

INSERT @Results
SELECT
    N'Lab VM physical memory',
    N'~8 GiB (recommended)',
    CONVERT(nvarchar(100), CAST(physical_memory_kb / 1024.0 / 1024.0 AS decimal(10,1))) + N' GiB',
    CASE WHEN physical_memory_kb BETWEEN 7340032 AND 9437184 THEN 'PASS' ELSE 'INFO' END
FROM sys.dm_os_sys_info;

-------------------------------------------------------------------------------
-- 3. Instance configuration
-------------------------------------------------------------------------------
INSERT @Results
SELECT N'max server memory (MB)', N'6144',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 6144 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'max server memory (MB)';

INSERT @Results
SELECT N'MAXDOP', N'2',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 2 THEN 'PASS' ELSE 'FAIL' END
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

INSERT @Results
SELECT N'Optimize for Ad Hoc Workloads', N'1',
       CONVERT(nvarchar(100), value_in_use),
       CASE WHEN value_in_use = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.configurations
WHERE name = N'optimize for ad hoc workloads';

-------------------------------------------------------------------------------
-- 4. Default paths
-------------------------------------------------------------------------------
INSERT @Results
SELECT N'Default Data Path', N'E:\SQLData\',
       COALESCE(CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultDataPath')), N'<NULL>'),
       CASE WHEN CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultDataPath')) = N'E:\SQLData\'
            THEN 'PASS' ELSE 'FAIL' END;

INSERT @Results
SELECT N'Default Log Path', N'F:\SQLLog\',
       COALESCE(CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultLogPath')), N'<NULL>'),
       CASE WHEN CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultLogPath')) = N'F:\SQLLog\'
            THEN 'PASS' ELSE 'FAIL' END;

INSERT @Results
SELECT N'Default Backup Path', N'G:\SQLBackup\',
       COALESCE(CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultBackupPath')), N'<NULL>'),
       CASE WHEN CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultBackupPath')) = N'G:\SQLBackup\'
            THEN 'PASS' ELSE 'FAIL' END;

-------------------------------------------------------------------------------
-- 5. WorkshopLab
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'WorkshopLab exists',
    N'ONLINE',
    COALESCE(state_desc, N'<missing>'),
    CASE WHEN state_desc = N'ONLINE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) AS x(dummy)
LEFT JOIN sys.databases d
    ON d.name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab Recovery Model', N'SIMPLE',
       recovery_model_desc,
       CASE WHEN recovery_model_desc = N'SIMPLE' THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab AUTO_CLOSE', N'OFF',
       CASE WHEN is_auto_close_on = 1 THEN N'ON' ELSE N'OFF' END,
       CASE WHEN is_auto_close_on = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab AUTO_SHRINK', N'OFF',
       CASE WHEN is_auto_shrink_on = 1 THEN N'ON' ELSE N'OFF' END,
       CASE WHEN is_auto_shrink_on = 0 THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT N'WorkshopLab PAGE_VERIFY', N'CHECKSUM',
       page_verify_option_desc,
       CASE WHEN page_verify_option_desc = N'CHECKSUM' THEN 'PASS' ELSE 'FAIL' END
FROM sys.databases
WHERE name = N'WorkshopLab';

INSERT @Results
SELECT
    N'WorkshopLab Data Path',
    N'E:\SQLData\WorkshopLab.mdf',
    physical_name,
    CASE WHEN physical_name = N'E:\SQLData\WorkshopLab.mdf' THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'WorkshopLab')
  AND type = 0;

INSERT @Results
SELECT
    N'WorkshopLab Log Path',
    N'F:\SQLLog\WorkshopLab_log.ldf',
    physical_name,
    CASE WHEN physical_name = N'F:\SQLLog\WorkshopLab_log.ldf' THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'WorkshopLab')
  AND type = 1;

INSERT @Results
SELECT
    N'WorkshopLab file size - ' + name,
    N'256 MB',
    CONVERT(nvarchar(50), size * 8 / 1024) + N' MB',
    CASE WHEN size = 32768 THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'WorkshopLab');

INSERT @Results
SELECT
    N'WorkshopLab file growth - ' + name,
    N'256 MB',
    CASE
        WHEN is_percent_growth = 1 THEN CONVERT(nvarchar(50), growth) + N'%'
        ELSE CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB'
    END,
    CASE WHEN is_percent_growth = 0 AND growth = 32768 THEN 'PASS' ELSE 'FAIL' END
FROM sys.master_files
WHERE database_id = DB_ID(N'WorkshopLab');

-------------------------------------------------------------------------------
-- 6. TempDB
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
    N'TempDB data file count',
    N'2',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files
WHERE type = 0;

INSERT @Results
SELECT
    N'TempDB log file count',
    N'1',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files
WHERE type = 1;

INSERT @Results
SELECT
    N'TempDB path - tempdev',
    N'D:\SQLTempDB\tempdb.mdf',
    COALESCE(MAX(CASE WHEN name = N'tempdev' THEN physical_name END), N'<missing>'),
    CASE WHEN MAX(CASE WHEN name = N'tempdev' THEN physical_name END) = N'D:\SQLTempDB\tempdb.mdf'
         THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB path - tempdev2',
    N'D:\SQLTempDB\tempdb2.ndf',
    COALESCE(MAX(CASE WHEN name = N'tempdev2' THEN physical_name END), N'<missing>'),
    CASE WHEN MAX(CASE WHEN name = N'tempdev2' THEN physical_name END) = N'D:\SQLTempDB\tempdb2.ndf'
         THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB path - templog',
    N'D:\SQLTempDB\templog.ldf',
    COALESCE(MAX(CASE WHEN name = N'templog' THEN physical_name END), N'<missing>'),
    CASE WHEN MAX(CASE WHEN name = N'templog' THEN physical_name END) = N'D:\SQLTempDB\templog.ldf'
         THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB size - ' + name,
    N'256 MB',
    CONVERT(nvarchar(50), size * 8 / 1024) + N' MB',
    CASE WHEN size = 32768 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

INSERT @Results
SELECT
    N'TempDB growth - ' + name,
    N'256 MB',
    CASE
        WHEN is_percent_growth = 1 THEN CONVERT(nvarchar(50), growth) + N'%'
        ELSE CONVERT(nvarchar(50), growth * 8 / 1024) + N' MB'
    END,
    CASE WHEN is_percent_growth = 0 AND growth = 32768 THEN 'PASS' ELSE 'FAIL' END
FROM tempdb.sys.database_files;

-------------------------------------------------------------------------------
-- 7. Output
-------------------------------------------------------------------------------
SELECT
    CheckName,
    ExpectedValue,
    ActualValue,
    Result
FROM @Results
ORDER BY
    CASE
        WHEN Result = 'FAIL' THEN 0
        WHEN Result = 'INFO' THEN 1
        ELSE 2
    END,
    CheckName;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = 'FAIL')
BEGIN
    PRINT '';
    PRINT 'Common Setup validation FAILED.';
    PRINT 'Do not continue with a workshop scenario until the failed checks are resolved.';
END
ELSE
BEGIN
    PRINT '';
    PRINT 'Common Setup validation PASSED.';
    PRINT 'The lab is ready for Scenario 01.';
END;
