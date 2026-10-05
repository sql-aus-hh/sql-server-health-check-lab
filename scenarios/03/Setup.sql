/*
    SQL Server Health Check Lab
    Scenario 03 - Health Check / Assess, Don't Assume
    Setup.sql

    Purpose:
      Build a reproducible environment with mixed health-check findings.

    WARNING:
      LAB / TEST SYSTEMS ONLY.

    Prerequisite:
      Common Setup has been applied and validated.

    No SQL Server service restart is required.
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @BackupDir nvarchar(4000) = N'G:\SQLBackup\Slot3',
    @HealthFullFile nvarchar(4000) = N'G:\SQLBackup\Slot3\HealthCheckApp_FULL.bak',
    @BackupJob sysname = N'SQLDays - Slot3 - Daily Full Backup',
    @CheckDbJob sysname = N'SQLDays - Slot3 - Weekly CHECKDB',
    @MaintenanceJob sysname = N'SQLDays - Slot3 - Nightly Maintenance',
    @OperatorName sysname = N'SQLDays - Slot3 - DBA Operator';

PRINT 'Scenario 03 - preparing Health Check lab...';

-------------------------------------------------------------------------------
-- 0. Preconditions
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab') IS NULL
    THROW 53000, 'WorkshopLab is missing. Run the Common Setup first.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_os_enumerate_fixed_drives
    WHERE fixed_drive_path = N'G:\'
)
    THROW 53001, 'Drive G: is required for Scenario 03 backup files.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_server_services
    WHERE servicename LIKE N'SQL Server Agent%'
      AND status_desc = N'Running'
)
    THROW 53002, 'SQL Server Agent must be running before Scenario 03 can be prepared.', 1;

EXEC master.dbo.xp_create_subdir @BackupDir;

-------------------------------------------------------------------------------
-- 1. Remove leftovers from previous Scenario 03 runs
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @BackupJob)
    EXEC msdb.dbo.sp_delete_job @job_name = @BackupJob, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @CheckDbJob)
    EXEC msdb.dbo.sp_delete_job @job_name = @CheckDbJob, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @MaintenanceJob)
    EXEC msdb.dbo.sp_delete_job @job_name = @MaintenanceJob, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
    EXEC msdb.dbo.sp_delete_operator @name = @OperatorName;

IF DB_ID(N'HealthCheckApp') IS NOT NULL
BEGIN
    ALTER DATABASE [HealthCheckApp] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [HealthCheckApp];
END;

IF DB_ID(N'LegacyReporting') IS NOT NULL
BEGIN
    ALTER DATABASE [LegacyReporting] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [LegacyReporting];
END;

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'HealthCheckApp';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'LegacyReporting';

-------------------------------------------------------------------------------
-- 2. Mixed instance state
-------------------------------------------------------------------------------
EXEC sys.sp_configure N'show advanced options', 1;
RECONFIGURE;

EXEC sys.sp_configure N'max server memory (MB)', 6144;
EXEC sys.sp_configure N'max degree of parallelism', 0;
EXEC sys.sp_configure N'cost threshold for parallelism', 50;
EXEC sys.sp_configure N'backup compression default', 1;
EXEC sys.sp_configure N'optimize for ad hoc workloads', 1;
RECONFIGURE;

-------------------------------------------------------------------------------
-- 3. TempDB - keep file count and size, but introduce uneven growth
-------------------------------------------------------------------------------
ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'tempdev',
    FILEGROWTH = 256MB
);

ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'tempdev2',
    FILEGROWTH = 64MB
);

ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'templog',
    FILEGROWTH = 256MB
);

-------------------------------------------------------------------------------
-- 4. HealthCheckApp
-------------------------------------------------------------------------------
DECLARE
    @MasterDataPath nvarchar(4000),
    @CreateHealthDb nvarchar(max);

SELECT @MasterDataPath =
       LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
FROM sys.master_files
WHERE database_id = 1
  AND file_id = 1;

SET @CreateHealthDb = N'
CREATE DATABASE [HealthCheckApp]
ON PRIMARY
(
    NAME = N''HealthCheckApp'',
    FILENAME = N''E:\SQLData\HealthCheckApp.mdf'',
    SIZE = 256MB,
    FILEGROWTH = 256MB
),
FILEGROUP [FG_Archive]
(
    NAME = N''HealthCheckApp_Archive'',
    FILENAME = N''' + REPLACE(@MasterDataPath,'''','''''') + N'HealthCheckApp_Archive.ndf'',
    SIZE = 64MB,
    FILEGROWTH = 64MB
)
LOG ON
(
    NAME = N''HealthCheckApp_log'',
    FILENAME = N''F:\SQLLog\HealthCheckApp_log.ldf'',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);';

EXEC sys.sp_executesql @CreateHealthDb;

ALTER DATABASE [HealthCheckApp] SET RECOVERY FULL;
ALTER DATABASE [HealthCheckApp] SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE [HealthCheckApp] SET AUTO_CLOSE OFF;
ALTER DATABASE [HealthCheckApp] SET AUTO_SHRINK OFF;
ALTER DATABASE [HealthCheckApp] SET COMPATIBILITY_LEVEL = 150;
ALTER DATABASE [HealthCheckApp] SET QUERY_STORE = OFF;

USE [HealthCheckApp];

CREATE TABLE dbo.BusinessTransaction
(
    TransactionId int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_BusinessTransaction PRIMARY KEY,
    ReferenceNo varchar(30) NOT NULL,
    Amount decimal(12,2) NOT NULL,
    CreatedUtc datetime2(0) NOT NULL
        CONSTRAINT DF_BusinessTransaction_CreatedUtc DEFAULT (SYSUTCDATETIME())
);

INSERT dbo.BusinessTransaction (ReferenceNo, Amount)
VALUES
    ('HC-1001', 125.00),
    ('HC-1002', 240.00),
    ('HC-1003', 515.00);

USE [master];

-------------------------------------------------------------------------------
-- 5. One Full backup for a FULL recovery database, but no Log backups
-------------------------------------------------------------------------------
BACKUP DATABASE [HealthCheckApp]
TO DISK = @HealthFullFile
WITH
    INIT,
    COMPRESSION,
    CHECKSUM,
    NAME = N'SQLDays Slot3 - HealthCheckApp FULL',
    STATS = 10;

USE [HealthCheckApp];

INSERT dbo.BusinessTransaction (ReferenceNo, Amount)
VALUES
    ('HC-AFTER-FULL-01', 999.00),
    ('HC-AFTER-FULL-02', 1999.00);

USE [master];

-------------------------------------------------------------------------------
-- 6. LegacyReporting
-------------------------------------------------------------------------------
CREATE DATABASE [LegacyReporting]
ON PRIMARY
(
    NAME = N'LegacyReporting',
    FILENAME = N'E:\SQLData\LegacyReporting.mdf',
    SIZE = 128MB,
    FILEGROWTH = 10%
)
LOG ON
(
    NAME = N'LegacyReporting_log',
    FILENAME = N'F:\SQLLog\LegacyReporting_log.ldf',
    SIZE = 64MB,
    FILEGROWTH = 10%
);

ALTER DATABASE [LegacyReporting] SET RECOVERY SIMPLE;
ALTER DATABASE [LegacyReporting] SET AUTO_CLOSE OFF;
ALTER DATABASE [LegacyReporting] SET AUTO_SHRINK ON;
ALTER DATABASE [LegacyReporting] SET PAGE_VERIFY TORN_PAGE_DETECTION;
ALTER DATABASE [LegacyReporting] SET QUERY_STORE = OFF;
ALTER DATABASE [LegacyReporting] SET TRUSTWORTHY ON;

USE [LegacyReporting];

CREATE TABLE dbo.ReportSnapshot
(
    SnapshotId int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_ReportSnapshot PRIMARY KEY,
    SourceName sysname NOT NULL,
    LoadedUtc datetime2(0) NOT NULL
        CONSTRAINT DF_ReportSnapshot_LoadedUtc DEFAULT (SYSUTCDATETIME())
);

INSERT dbo.ReportSnapshot (SourceName)
VALUES (N'ERP_REBUILDABLE_SOURCE');

USE [master];

-------------------------------------------------------------------------------
-- 7. Operator with intentionally unusable lab address
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_add_operator
    @name = @OperatorName,
    @enabled = 1,
    @email_address = N'healthcheck@example.invalid';

-------------------------------------------------------------------------------
-- 8. Daily Full backup job
-------------------------------------------------------------------------------
DECLARE @BackupJobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = @BackupJob,
    @enabled = 1,
    @description = N'SQLDays Slot 3 lab: daily Full backup only.',
    @notify_level_email = 2,
    @notify_email_operator_name = @OperatorName,
    @job_id = @BackupJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @BackupJobId,
    @step_name = N'Full Backup - HealthCheckApp',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'BACKUP DATABASE [HealthCheckApp]
TO DISK = N''G:\SQLBackup\Slot3\HealthCheckApp_FULL.bak''
WITH INIT, COMPRESSION, CHECKSUM,
NAME = N''SQLDays Slot3 - Scheduled Full'',
STATS = 10;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobschedule
    @job_id = @BackupJobId,
    @name = N'SQLDays - Slot3 - Daily 00:30',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 003000;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @BackupJobId;

-------------------------------------------------------------------------------
-- 9. Disabled weekly CHECKDB job
-------------------------------------------------------------------------------
DECLARE @CheckDbJobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = @CheckDbJob,
    @enabled = 0,
    @description = N'SQLDays Slot 3 lab: CHECKDB job exists but is disabled.',
    @job_id = @CheckDbJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @CheckDbJobId,
    @step_name = N'CHECKDB - HealthCheckApp',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'DBCC CHECKDB (N''HealthCheckApp'') WITH NO_INFOMSGS;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobschedule
    @job_id = @CheckDbJobId,
    @name = N'SQLDays - Slot3 - Weekly Sunday 03:00',
    @enabled = 1,
    @freq_type = 8,
    @freq_interval = 1,
    @active_start_time = 030000;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @CheckDbJobId;

-------------------------------------------------------------------------------
-- 10. Enabled maintenance job containing SHRINKDATABASE
-------------------------------------------------------------------------------
DECLARE @MaintenanceJobId uniqueidentifier;

EXEC msdb.dbo.sp_add_job
    @job_name = @MaintenanceJob,
    @enabled = 1,
    @description = N'SQLDays Slot 3 lab: intentionally questionable maintenance.',
    @job_id = @MaintenanceJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @MaintenanceJobId,
    @step_name = N'Update Stats and Shrink',
    @subsystem = N'TSQL',
    @database_name = N'HealthCheckApp',
    @command = N'EXEC sys.sp_updatestats;
DBCC SHRINKDATABASE (N''HealthCheckApp'', 10) WITH NO_INFOMSGS;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobschedule
    @job_id = @MaintenanceJobId,
    @name = N'SQLDays - Slot3 - Daily 02:00',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000;

EXEC msdb.dbo.sp_add_jobserver
    @job_id = @MaintenanceJobId;

-------------------------------------------------------------------------------
-- 11. Run the Full backup job once so a green history exists
-------------------------------------------------------------------------------
DECLARE
    @AgentSessionId int = (SELECT MAX(session_id) FROM msdb.dbo.syssessions),
    @WaitCount int = 0;

EXEC msdb.dbo.sp_start_job @job_id = @BackupJobId;

WHILE @WaitCount < 60
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysjobactivity
        WHERE session_id = @AgentSessionId
          AND job_id = @BackupJobId
          AND start_execution_date IS NOT NULL
          AND stop_execution_date IS NOT NULL
    )
        BREAK;

    WAITFOR DELAY '00:00:01';
    SET @WaitCount += 1;
END;

IF @WaitCount >= 60
    THROW 53003, 'Scenario 03 Full backup job did not finish within 60 seconds.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = @BackupJobId
      AND step_id = 0
      AND run_status = 1
)
    THROW 53004, 'Scenario 03 Full backup job did not complete successfully.', 1;

PRINT '';
PRINT 'Scenario 03 setup completed.';
PRINT 'Run scenarios/03/Validate.sql before starting the exercise.';
PRINT 'HealthCheckApp context: RPO 15 min / RTO 60 min.';
PRINT 'LegacyReporting context: rebuildable from source within about 4 hours.';
