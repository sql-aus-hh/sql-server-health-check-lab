/*
    SQL Server Health Check Lab
    Scenario 03 - Health Check / Assess, Don't Assume
    Cleanup.sql

    Purpose:
      Remove Scenario 03 artifacts and restore the Common Setup baseline.

    Note:
      G:\SQLBackup\Slot3\HealthCheckApp_FULL.bak is intentionally left
      on disk. A future Setup run overwrites it with WITH INIT.

    WARNING:
      LAB / TEST SYSTEMS ONLY.
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @BackupJob sysname = N'SQLDays - Slot3 - Daily Full Backup',
    @CheckDbJob sysname = N'SQLDays - Slot3 - Weekly CHECKDB',
    @MaintenanceJob sysname = N'SQLDays - Slot3 - Nightly Maintenance',
    @OperatorName sysname = N'SQLDays - Slot3 - DBA Operator';

-------------------------------------------------------------------------------
-- 1. Restore instance baseline
-------------------------------------------------------------------------------
EXEC sys.sp_configure N'show advanced options', 1;
RECONFIGURE;

EXEC sys.sp_configure N'max server memory (MB)', 6144;
EXEC sys.sp_configure N'max degree of parallelism', 2;
EXEC sys.sp_configure N'cost threshold for parallelism', 50;
EXEC sys.sp_configure N'backup compression default', 1;
EXEC sys.sp_configure N'optimize for ad hoc workloads', 1;
RECONFIGURE;

-------------------------------------------------------------------------------
-- 2. Restore TempDB growth baseline
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
    FILEGROWTH = 256MB
);

ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'templog',
    FILEGROWTH = 256MB
);

-------------------------------------------------------------------------------
-- 3. SQL Agent objects
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @BackupJob)
    EXEC msdb.dbo.sp_delete_job @job_name = @BackupJob, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @CheckDbJob)
    EXEC msdb.dbo.sp_delete_job @job_name = @CheckDbJob, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @MaintenanceJob)
    EXEC msdb.dbo.sp_delete_job @job_name = @MaintenanceJob, @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
    EXEC msdb.dbo.sp_delete_operator @name = @OperatorName;

-------------------------------------------------------------------------------
-- 4. Databases
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
-- 5. Backup / restore history
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'HealthCheckApp';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'LegacyReporting';

PRINT '';
PRINT 'Scenario 03 cleanup completed.';
PRINT 'No SQL Server service restart is required.';
PRINT 'Run setup/02-Validate-Setup.sql to confirm the Common Setup baseline.';
