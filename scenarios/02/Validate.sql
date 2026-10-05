/*
    SQL Server Health Check Lab
    Scenario 02 - Take Ownership / Recovery Readiness
    Validate.sql

    Purpose:
      Verify that the intended Slot 2 starting state exists.

    Important:
      PASS means the lab scenario was reproduced as intended.
      It does NOT mean the operational configuration is healthy.
*/

USE [master];
GO

SET NOCOUNT ON;

DECLARE @Results table
(
    CheckName nvarchar(240) NOT NULL,
    ExpectedValue nvarchar(4000) NULL,
    ActualValue nvarchar(4000) NULL,
    Result varchar(10) NOT NULL
);

DECLARE
    @JobName sysname = N'SQLDays - Slot2 - WorkshopOps Backup',
    @OperatorName sysname = N'SQLDays - DBA Operator';

-------------------------------------------------------------------------------
-- 1. Databases
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'WorkshopOps exists',
    N'ONLINE',
    COALESCE(state_desc, N'<missing>'),
    CASE WHEN state_desc = N'ONLINE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'WorkshopOps';

INSERT @Results
SELECT
    N'WorkshopOps recovery model',
    N'FULL',
    COALESCE(recovery_model_desc, N'<missing>'),
    CASE WHEN recovery_model_desc = N'FULL' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'WorkshopOps';

INSERT @Results
SELECT
    N'WorkshopOps_Audit exists',
    N'ONLINE',
    COALESCE(state_desc, N'<missing>'),
    CASE WHEN state_desc = N'ONLINE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d ON d.name = N'WorkshopOps_Audit';

INSERT @Results
SELECT
    N'WorkshopLab_Restore absent before exercise',
    N'ABSENT',
    CASE WHEN DB_ID(N'WorkshopLab_Restore') IS NULL THEN N'ABSENT' ELSE N'PRESENT' END,
    CASE WHEN DB_ID(N'WorkshopLab_Restore') IS NULL THEN 'PASS' ELSE 'FAIL' END;

-------------------------------------------------------------------------------
-- 2. Marker state
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopOps') IS NOT NULL
BEGIN
    INSERT @Results
    SELECT
        N'WorkshopOps marker count',
        N'4',
        CONVERT(nvarchar(50), COUNT(*)),
        CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END
    FROM WorkshopOps.dbo.LabMarker;

    INSERT @Results
    SELECT
        N'Marker - ' + v.MarkerName,
        N'PRESENT',
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM WorkshopOps.dbo.LabMarker m
            WHERE m.MarkerName = v.MarkerName
        )
        THEN N'PRESENT' ELSE N'MISSING' END,
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM WorkshopOps.dbo.LabMarker m
            WHERE m.MarkerName = v.MarkerName
        )
        THEN 'PASS' ELSE 'FAIL' END
    FROM (VALUES
        (N'FULL_BASELINE'),
        (N'LOG_01_APPLIED'),
        (N'SLOT2_TARGET'),
        (N'AFTER_TARGET_DO_NOT_INCLUDE')
    ) v(MarkerName);

    INSERT @Results
    SELECT
        N'WorkshopOps order count',
        N'6',
        CONVERT(nvarchar(50), COUNT(*)),
        CASE WHEN COUNT(*) = 6 THEN 'PASS' ELSE 'FAIL' END
    FROM WorkshopOps.dbo.Orders;

    INSERT @Results
    SELECT
        N'Order - OPS-1201 target',
        N'PRESENT',
        CASE WHEN EXISTS
        (
            SELECT 1 FROM WorkshopOps.dbo.Orders WHERE OrderNo = 'OPS-1201'
        )
        THEN N'PRESENT' ELSE N'MISSING' END,
        CASE WHEN EXISTS
        (
            SELECT 1 FROM WorkshopOps.dbo.Orders WHERE OrderNo = 'OPS-1201'
        )
        THEN 'PASS' ELSE 'FAIL' END;

    INSERT @Results
    SELECT
        N'Order - OPS-1301 after target',
        N'PRESENT in source',
        CASE WHEN EXISTS
        (
            SELECT 1 FROM WorkshopOps.dbo.Orders WHERE OrderNo = 'OPS-1301'
        )
        THEN N'PRESENT in source' ELSE N'MISSING' END,
        CASE WHEN EXISTS
        (
            SELECT 1 FROM WorkshopOps.dbo.Orders WHERE OrderNo = 'OPS-1301'
        )
        THEN 'PASS' ELSE 'FAIL' END;
END;

-------------------------------------------------------------------------------
-- 3. Backup history
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'WorkshopOps regular FULL backups',
    N'1',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'WorkshopOps'
  AND type = 'D'
  AND is_copy_only = 0;

INSERT @Results
SELECT
    N'WorkshopOps LOG backups',
    N'3',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'WorkshopOps'
  AND type = 'L';

INSERT @Results
SELECT
    N'WorkshopOps COPY_ONLY FULL backups',
    N'1',
    CONVERT(nvarchar(50), COUNT(*)),
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'WorkshopOps'
  AND type = 'D'
  AND is_copy_only = 1;

INSERT @Results
SELECT
    N'WorkshopOps_Audit backup history',
    N'0 backups',
    CONVERT(nvarchar(50), COUNT(*)) + N' backups',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.backupset
WHERE database_name = N'WorkshopOps_Audit';

-------------------------------------------------------------------------------
-- 4. Expected backup files exist
-------------------------------------------------------------------------------
DECLARE @Files table
(
    FilePath nvarchar(4000) NOT NULL,
    FileExists int NULL,
    IsDirectory int NULL,
    ParentDirectoryExists int NULL
);

DECLARE
    @FilePath nvarchar(4000),
    @FileCheck table
    (
        FileExists int,
        IsDirectory int,
        ParentDirectoryExists int
    );

DECLARE FileCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT FilePath
FROM (VALUES
    (N'G:\SQLBackup\Slot2\WorkshopOps_FULL.bak'),
    (N'G:\SQLBackup\Slot2\WorkshopOps_LOG_01.trn'),
    (N'G:\SQLBackup\Slot2\WorkshopOps_LOG_02.trn'),
    (N'G:\SQLBackup\Slot2\WorkshopOps_LOG_03.trn'),
    (N'G:\SQLBackup\Slot2\WorkshopOps_JOB_COPYONLY.bak')
) f(FilePath);

OPEN FileCursor;
FETCH NEXT FROM FileCursor INTO @FilePath;

WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @FileCheck;

    INSERT @FileCheck
    EXEC master.dbo.xp_fileexist @FilePath;

    INSERT @Files (FilePath, FileExists, IsDirectory, ParentDirectoryExists)
    SELECT @FilePath, FileExists, IsDirectory, ParentDirectoryExists
    FROM @FileCheck;

    FETCH NEXT FROM FileCursor INTO @FilePath;
END;

CLOSE FileCursor;
DEALLOCATE FileCursor;

INSERT @Results
SELECT
    N'Backup file - ' + RIGHT(FilePath, CHARINDEX('\', REVERSE(FilePath)) - 1),
    N'EXISTS',
    CASE WHEN FileExists = 1 THEN N'EXISTS' ELSE N'MISSING' END,
    CASE WHEN FileExists = 1 THEN 'PASS' ELSE 'FAIL' END
FROM @Files;

-------------------------------------------------------------------------------
-- 5. SQL Agent job
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'SQL Agent job exists',
    @JobName,
    COALESCE(j.name, N'<missing>'),
    CASE WHEN j.job_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysjobs j
    ON j.name = @JobName;

INSERT @Results
SELECT TOP (1)
    N'SQL Agent job last outcome',
    N'SUCCEEDED',
    CASE h.run_status
        WHEN 0 THEN N'FAILED'
        WHEN 1 THEN N'SUCCEEDED'
        WHEN 2 THEN N'RETRY'
        WHEN 3 THEN N'CANCELED'
        WHEN 4 THEN N'IN PROGRESS'
        ELSE N'<unknown>'
    END,
    CASE WHEN h.run_status = 1 THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobhistory h
  ON h.job_id = j.job_id
 AND h.step_id = 0
WHERE j.name = @JobName
ORDER BY h.instance_id DESC;

INSERT @Results
SELECT
    N'Job command includes WorkshopOps',
    N'YES',
    CASE WHEN MAX(CASE WHEN s.command LIKE N'%WorkshopOps%' THEN 1 ELSE 0 END) = 1
         THEN N'YES' ELSE N'NO' END,
    CASE WHEN MAX(CASE WHEN s.command LIKE N'%WorkshopOps%' THEN 1 ELSE 0 END) = 1
         THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobsteps s ON s.job_id = j.job_id
WHERE j.name = @JobName;

INSERT @Results
SELECT
    N'Job command excludes WorkshopOps_Audit',
    N'NOT REFERENCED',
    CASE WHEN MAX(CASE WHEN s.command LIKE N'%WorkshopOps_Audit%' THEN 1 ELSE 0 END) = 1
         THEN N'REFERENCED' ELSE N'NOT REFERENCED' END,
    CASE WHEN MAX(CASE WHEN s.command LIKE N'%WorkshopOps_Audit%' THEN 1 ELSE 0 END) = 0
         THEN 'PASS' ELSE 'FAIL' END
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobsteps s ON s.job_id = j.job_id
WHERE j.name = @JobName;

-------------------------------------------------------------------------------
-- 6. Operator / notification setup
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Operator exists',
    @OperatorName,
    COALESCE(o.name, N'<missing>'),
    CASE WHEN o.id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysoperators o
    ON o.name = @OperatorName;

INSERT @Results
SELECT
    N'Operator email',
    N'dba@example.invalid',
    COALESCE(o.email_address, N'<missing>'),
    CASE WHEN o.email_address = N'dba@example.invalid' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN msdb.dbo.sysoperators o
    ON o.name = @OperatorName;

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
    CASE WHEN Result = 'FAIL' THEN 0 ELSE 1 END,
    CheckName;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = 'FAIL')
BEGIN
    PRINT '';
    PRINT 'Scenario 02 validation FAILED.';
    PRINT 'Resolve the failed preparation checks before starting the exercise.';
END
ELSE
BEGIN
    PRINT '';
    PRINT 'Scenario 02 validation PASSED.';
    PRINT 'The Take Ownership / Recovery Readiness exercise is ready.';
END;
