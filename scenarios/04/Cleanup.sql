/*
    SQL Server Health Check Lab
    Scenario 04 - Troubleshooting
    Cleanup.sql

    Purpose:
      Stop marked Blocking demo sessions and remove WorkshopTrouble.

    WARNING:
      LAB / TEST SYSTEMS ONLY.
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @KillCommands nvarchar(max) = N'';

SELECT @KillCommands +=
       N'KILL ' + CONVERT(nvarchar(20),session_id) + N';' + CHAR(13) + CHAR(10)
FROM sys.dm_exec_sessions
WHERE session_id <> @@SPID
  AND context_info IN
  (
      0x534C4F54345F424C4F434B4552,
      0x534C4F54345F574149544552
  );

IF @KillCommands <> N''
BEGIN
    PRINT 'Stopping marked Scenario 04 sessions...';
    EXEC sys.sp_executesql @KillCommands;
END;

IF DB_ID(N'WorkshopTrouble') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopTrouble] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [WorkshopTrouble];
END;

PRINT '';
PRINT 'Scenario 04 cleanup completed.';
PRINT 'No SQL Server service restart is required.';
PRINT 'Run setup/02-Validate-Setup.sql to confirm the Common Setup baseline.';
