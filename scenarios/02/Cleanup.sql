/*
    SQL Server Health Check Lab
    Scenario 02 - Take Ownership / Recovery Readiness
    Cleanup.sql

    Purpose:
      Remove Scenario 02 databases, SQL Agent objects and backup history.

    Note:
      Backup files under G:\SQLBackup\Slot2 are intentionally left on disk.
      The next Scenario 02 Setup uses WITH INIT and overwrites them.

    WARNING:
      LAB / TEST SYSTEMS ONLY.
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @JobName sysname = N'SQLDays - Slot2 - WorkshopOps Backup',
    @OperatorName sysname = N'SQLDays - DBA Operator';

-------------------------------------------------------------------------------
-- 1. SQL Agent objects
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    EXEC msdb.dbo.sp_delete_job
        @job_name = @JobName,
        @delete_unused_schedule = 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
    EXEC msdb.dbo.sp_delete_operator
        @name = @OperatorName;

-------------------------------------------------------------------------------
-- 2. Databases
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

-------------------------------------------------------------------------------
-- 3. Backup history
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopOps';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopOps_Audit';
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopLab_Restore';

PRINT '';
PRINT 'Scenario 02 cleanup completed.';
PRINT 'No SQL Server service restart is required.';
PRINT 'Run setup/02-Validate-Setup.sql if you want to confirm the Common Setup baseline.';
