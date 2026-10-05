/*
    SQL Server Health Check Lab
    Scenario 02 - Take Ownership / Recovery Readiness
    Setup.sql

    Purpose:
      Create the operational handover / recovery scenario used in Slot 2
      of the SQLDays 2026 workshop.

    WARNING:
      LAB / TEST SYSTEMS ONLY.

    Prerequisite:
      Common Setup has been applied and validated.

    Result:
      - WorkshopOps
      - WorkshopOps_Audit
      - controlled FULL + LOG backup chain
      - successful SQL Agent COPY_ONLY backup job
      - intentionally incomplete operational coverage
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @BackupDir nvarchar(4000) = N'G:\SQLBackup\Slot2',
    @FullFile nvarchar(4000) = N'G:\SQLBackup\Slot2\WorkshopOps_FULL.bak',
    @Log01File nvarchar(4000) = N'G:\SQLBackup\Slot2\WorkshopOps_LOG_01.trn',
    @Log02File nvarchar(4000) = N'G:\SQLBackup\Slot2\WorkshopOps_LOG_02.trn',
    @Log03File nvarchar(4000) = N'G:\SQLBackup\Slot2\WorkshopOps_LOG_03.trn',
    @JobCopyFile nvarchar(4000) = N'G:\SQLBackup\Slot2\WorkshopOps_JOB_COPYONLY.bak',
    @JobName sysname = N'SQLDays - Slot2 - WorkshopOps Backup',
    @OperatorName sysname = N'SQLDays - DBA Operator';

PRINT 'Scenario 02 - preparing Take Ownership / Recovery Readiness lab...';

-------------------------------------------------------------------------------
-- 0. Preconditions
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab') IS NULL
    THROW 52000, 'WorkshopLab is missing. Run the Common Setup first.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_os_enumerate_fixed_drives
    WHERE fixed_drive_path = N'G:\'
)
    THROW 52001, 'Drive G: is required for Scenario 02 backup files.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_server_services
    WHERE servicename LIKE N'SQL Server Agent%'
      AND status_desc = N'Running'
)
    THROW 52002, 'SQL Server Agent must be running before Scenario 02 can be prepared.', 1;

EXEC master.dbo.xp_create_subdir @BackupDir;

-------------------------------------------------------------------------------
-- 1. Remove leftovers from previous Scenario 02 runs
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab_Restore') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopLab_Restore] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [WorkshopLab_Restore];
END;

IF DB_ID(N'WorkshopOps') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopOps] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [WorkshopOps];
END;

IF DB_ID(N'WorkshopOps_Audit') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopOps_Audit] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [WorkshopOps_Audit];
END;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
    EXEC msdb.dbo.sp_delete_operator @name = @OperatorName;

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopOps';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopOps_Audit';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopLab_Restore';

-------------------------------------------------------------------------------
-- 2. Create WorkshopOps
-------------------------------------------------------------------------------
CREATE DATABASE [WorkshopOps]
ON PRIMARY
(
    NAME = N'WorkshopOps',
    FILENAME = N'E:\SQLData\WorkshopOps.mdf',
    SIZE = 128MB,
    FILEGROWTH = 128MB
)
LOG ON
(
    NAME = N'WorkshopOps_log',
    FILENAME = N'F:\SQLLog\WorkshopOps_log.ldf',
    SIZE = 128MB,
    FILEGROWTH = 128MB
);

ALTER DATABASE [WorkshopOps] SET RECOVERY FULL;
ALTER DATABASE [WorkshopOps] SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE [WorkshopOps] SET AUTO_CLOSE OFF;
ALTER DATABASE [WorkshopOps] SET AUTO_SHRINK OFF;

USE [WorkshopOps];

CREATE TABLE dbo.LabMarker
(
    MarkerId int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_LabMarker PRIMARY KEY,
    MarkerName sysname NOT NULL,
    MarkerUtc datetime2(0) NOT NULL
        CONSTRAINT DF_LabMarker_Utc DEFAULT (SYSUTCDATETIME())
);

CREATE TABLE dbo.Orders
(
    OrderId int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Orders PRIMARY KEY,
    OrderNo varchar(20) NOT NULL,
    Amount decimal(12,2) NOT NULL,
    CreatedUtc datetime2(0) NOT NULL
        CONSTRAINT DF_Orders_Created DEFAULT (SYSUTCDATETIME())
);

INSERT dbo.LabMarker (MarkerName)
VALUES (N'FULL_BASELINE');

INSERT dbo.Orders (OrderNo, Amount)
VALUES
    ('OPS-1001', 125.00),
    ('OPS-1002', 240.00),
    ('OPS-1003',  99.95);

USE [master];

-------------------------------------------------------------------------------
-- 3. Baseline FULL backup
-------------------------------------------------------------------------------
BACKUP DATABASE [WorkshopOps]
TO DISK = @FullFile
WITH
    INIT,
    COMPRESSION,
    CHECKSUM,
    NAME = N'SQLDays Slot2 - WorkshopOps FULL baseline',
    STATS = 10;

-------------------------------------------------------------------------------
-- 4. LOG 01
-------------------------------------------------------------------------------
USE [WorkshopOps];

INSERT dbo.LabMarker (MarkerName)
VALUES (N'LOG_01_APPLIED');

INSERT dbo.Orders (OrderNo, Amount)
VALUES ('OPS-1101', 310.00);

USE [master];

BACKUP LOG [WorkshopOps]
TO DISK = @Log01File
WITH
    INIT,
    COMPRESSION,
    CHECKSUM,
    NAME = N'SQLDays Slot2 - WorkshopOps LOG 01',
    STATS = 10;

-------------------------------------------------------------------------------
-- 5. LOG 02 - target state
-------------------------------------------------------------------------------
USE [WorkshopOps];

INSERT dbo.LabMarker (MarkerName)
VALUES (N'SLOT2_TARGET');

INSERT dbo.Orders (OrderNo, Amount)
VALUES ('OPS-1201', 515.00);

USE [master];

BACKUP LOG [WorkshopOps]
TO DISK = @Log02File
WITH
    INIT,
    COMPRESSION,
    CHECKSUM,
    NAME = N'SQLDays Slot2 - WorkshopOps LOG 02 - TARGET',
    STATS = 10;

-------------------------------------------------------------------------------
-- 6. LOG 03 - state that must NOT be included in the requested restore
-------------------------------------------------------------------------------
USE [WorkshopOps];

INSERT dbo.LabMarker (MarkerName)
VALUES (N'AFTER_TARGET_DO_NOT_INCLUDE');

INSERT dbo.Orders (OrderNo, Amount)
VALUES ('OPS-1301', 999.00);

USE [master];

BACKUP LOG [WorkshopOps]
TO DISK = @Log03File
WITH
    INIT,
    COMPRESSION,
    CHECKSUM,
    NAME = N'SQLDays Slot2 - WorkshopOps LOG 03 - AFTER TARGET',
    STATS = 10;

-------------------------------------------------------------------------------
-- 7. Create related Audit database that is intentionally not protected
--    by the prepared SQL Agent backup job
-------------------------------------------------------------------------------
CREATE DATABASE [WorkshopOps_Audit]
ON PRIMARY
(
    NAME = N'WorkshopOps_Audit',
    FILENAME = N'E:\SQLData\WorkshopOps_Audit.mdf',
    SIZE = 64MB,
    FILEGROWTH = 64MB
)
LOG ON
(
    NAME = N'WorkshopOps_Audit_log',
    FILENAME = N'F:\SQLLog\WorkshopOps_Audit_log.ldf',
    SIZE = 64MB,
    FILEGROWTH = 64MB
);

ALTER DATABASE [WorkshopOps_Audit] SET RECOVERY FULL;
ALTER DATABASE [WorkshopOps_Audit] SET PAGE_VERIFY CHECKSUM;

USE [WorkshopOps_Audit];

CREATE TABLE dbo.AuditEvent
(
    AuditEventId int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_AuditEvent PRIMARY KEY,
    EventName nvarchar(200) NOT NULL,
    EventUtc datetime2(0) NOT NULL
        CONSTRAINT DF_AuditEvent_EventUtc DEFAULT (SYSUTCDATETIME())
);

INSERT dbo.AuditEvent (EventName)
VALUES (N'AUDIT_DB_IS_PART_OF_THE_APPLICATION_BUT_NOT_BACKED_UP_BY_THE_JOB');

USE [master];

-------------------------------------------------------------------------------
-- 8. Operator exists, but the address is intentionally not production-ready
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_add_operator
    @name = @OperatorName,
    @enabled = 1,
    @email_address = N'dba@example.invalid';

-------------------------------------------------------------------------------
-- 9. Successful SQL Agent job.
--
-- It creates only a COPY_ONLY FULL backup of WorkshopOps.
-- WorkshopOps_Audit is intentionally excluded.
-------------------------------------------------------------------------------
DECLARE @JobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = @JobName,
    @enabled = 1,
    @description = N'SQLDays Slot 2 lab job. Intentionally backs up only WorkshopOps.',
    @notify_level_email = 2,
    @notify_email_operator_name = @OperatorName,
    @job_id = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_name = N'COPY_ONLY Full Backup - WorkshopOps',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'BACKUP DATABASE [WorkshopOps]
TO DISK = N''G:\SQLBackup\Slot2\WorkshopOps_JOB_COPYONLY.bak''
WITH COPY_ONLY, INIT, COMPRESSION, CHECKSUM,
NAME = N''SQLDays Slot2 - SQL Agent COPY_ONLY Full'',
STATS = 10;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobschedule
    @job_id = @JobId,
    @name = N'SQLDays - Slot2 - Daily 01:00',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 010000;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @JobId;

-------------------------------------------------------------------------------
-- 10. Execute the SQL Agent job once so job history looks healthy
-------------------------------------------------------------------------------
DECLARE
    @AgentSessionId int = (SELECT MAX(session_id) FROM msdb.dbo.syssessions),
    @WaitCount int = 0;

EXEC msdb.dbo.sp_start_job @job_id = @JobId;

WHILE @WaitCount < 60
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysjobactivity
        WHERE session_id = @AgentSessionId
          AND job_id = @JobId
          AND start_execution_date IS NOT NULL
          AND stop_execution_date IS NOT NULL
    )
        BREAK;

    WAITFOR DELAY '00:00:01';
    SET @WaitCount += 1;
END;

IF @WaitCount >= 60
    THROW 52003, 'The Scenario 02 SQL Agent backup job did not finish within 60 seconds.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = @JobId
      AND step_id = 0
      AND run_status = 1
)
    THROW 52004, 'The Scenario 02 SQL Agent backup job did not complete successfully.', 1;

-------------------------------------------------------------------------------
-- 11. Final guard: Audit DB must have no backup history
-------------------------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM msdb.dbo.backupset
    WHERE database_name = N'WorkshopOps_Audit'
)
    THROW 52005, 'WorkshopOps_Audit unexpectedly has backup history. Scenario 02 is not in the intended state.', 1;

PRINT '';
PRINT 'Scenario 02 setup completed.';
PRINT 'Run scenarios/02/Validate.sql before starting the exercise.';
PRINT 'Requested recovery target: SLOT2_TARGET / OPS-1201.';
PRINT 'Do not include AFTER_TARGET_DO_NOT_INCLUDE / OPS-1301.';
