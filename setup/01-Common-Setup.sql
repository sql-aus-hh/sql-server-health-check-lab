/*
    SQL Server Health Check Lab
    Common Setup
    01-Common-Setup.sql

    Purpose:
      Create a deterministic baseline for all SQLDays 2026 workshop scenarios.

    WARNING:
      LAB / TEST SYSTEMS ONLY.

    Expected VM:
      SQL Server 2025 Developer
      Windows
      2 vCPU / 8 GiB RAM
      C: system
      D: TempDB
      E: Data
      F: Log
      G: Backup

    IMPORTANT:
      Restart the SQL Server service after this script.
      Then run 02-Validate-Setup.sql.
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT 'SQL Server Health Check Lab - Common Setup';
PRINT '------------------------------------------------------------';

-------------------------------------------------------------------------------
-- 0. Safety checks
-------------------------------------------------------------------------------
IF CONVERT(nvarchar(128), SERVERPROPERTY('EngineEdition')) IN (N'5', N'6', N'8')
    THROW 51000, 'This lab expects a regular SQL Server instance, not Azure SQL Database / Managed Instance.', 1;

DECLARE @MissingDrives nvarchar(4000) = N'';

;WITH RequiredDrives AS
(
    SELECT N'D:\' AS DriveRoot
    UNION ALL SELECT N'E:\'
    UNION ALL SELECT N'F:\'
    UNION ALL SELECT N'G:\'
)
SELECT @MissingDrives += DriveRoot + N' '
FROM RequiredDrives r
WHERE NOT EXISTS
(
    SELECT 1
    FROM sys.dm_os_enumerate_fixed_drives
    WHERE fixed_drive_path = r.DriveRoot
);

IF @MissingDrives <> N''
    THROW 51001, 'Required lab drives D:, E:, F: and G: must exist before running the Common Setup.', 1;

-------------------------------------------------------------------------------
-- 1. Create lab directories
-------------------------------------------------------------------------------
EXEC master.dbo.xp_create_subdir N'D:\SQLTempDB';
EXEC master.dbo.xp_create_subdir N'E:\SQLData';
EXEC master.dbo.xp_create_subdir N'F:\SQLLog';
EXEC master.dbo.xp_create_subdir N'G:\SQLBackup';

-------------------------------------------------------------------------------
-- 2. Instance baseline
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
-- 3. Instance default paths
-------------------------------------------------------------------------------
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'DefaultData',
    REG_SZ,
    N'E:\SQLData\';

EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'DefaultLog',
    REG_SZ,
    N'F:\SQLLog\';

EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'BackupDirectory',
    REG_SZ,
    N'G:\SQLBackup\';

-------------------------------------------------------------------------------
-- 4. WorkshopLab
--
-- Recreate the database to guarantee a deterministic baseline.
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopLab] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [WorkshopLab];
END;

CREATE DATABASE [WorkshopLab]
ON PRIMARY
(
    NAME = N'WorkshopLab',
    FILENAME = N'E:\SQLData\WorkshopLab.mdf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
)
LOG ON
(
    NAME = N'WorkshopLab_log',
    FILENAME = N'F:\SQLLog\WorkshopLab_log.ldf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

ALTER DATABASE [WorkshopLab] SET AUTO_CLOSE OFF;
ALTER DATABASE [WorkshopLab] SET AUTO_SHRINK OFF;
ALTER DATABASE [WorkshopLab] SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE [WorkshopLab] SET RECOVERY SIMPLE;

-------------------------------------------------------------------------------
-- 5. TempDB baseline
--
-- Desired state:
--   tempdev   256 MB  D:\SQLTempDB\tempdb.mdf
--   tempdev2  256 MB  D:\SQLTempDB\tempdb2.ndf
--   templog   256 MB  D:\SQLTempDB\templog.ldf
--   growth    256 MB for every file
--
-- Extra TempDB DATA files are emptied and removed where possible.
-------------------------------------------------------------------------------
DECLARE
    @Name sysname,
    @Sql nvarchar(max);

-- Normalize primary data file.
ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'tempdev',
    FILENAME = N'D:\SQLTempDB\tempdb.mdf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

-- Normalize log file.
ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'templog',
    FILENAME = N'D:\SQLTempDB\templog.ldf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

-- Make sure the second data file exists.
IF NOT EXISTS
(
    SELECT 1
    FROM tempdb.sys.database_files
    WHERE name = N'tempdev2'
      AND type = 0
)
BEGIN
    ALTER DATABASE [tempdb]
    ADD FILE
    (
        NAME = N'tempdev2',
        FILENAME = N'D:\SQLTempDB\tempdb2.ndf',
        SIZE = 256MB,
        FILEGROWTH = 256MB
    );
END
ELSE
BEGIN
    ALTER DATABASE [tempdb]
    MODIFY FILE
    (
        NAME = N'tempdev2',
        FILENAME = N'D:\SQLTempDB\tempdb2.ndf',
        SIZE = 256MB,
        FILEGROWTH = 256MB
    );
END;

-- Remove any additional TempDB DATA files.
DECLARE ExtraTempdbFiles CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM tempdb.sys.database_files
WHERE type = 0
  AND name NOT IN (N'tempdev', N'tempdev2');

OPEN ExtraTempdbFiles;
FETCH NEXT FROM ExtraTempdbFiles INTO @Name;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @Sql = N'USE [tempdb]; DBCC SHRINKFILE (N''' +
                   REPLACE(@Name,'''','''''') +
                   N''', EMPTYFILE) WITH NO_INFOMSGS;';
        EXEC sys.sp_executesql @Sql;

        SET @Sql = N'ALTER DATABASE [tempdb] REMOVE FILE [' +
                   REPLACE(@Name,']',']]') + N'];';
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        PRINT CONCAT(
            'Could not remove extra TempDB file ', @Name,
            '. Retry after SQL Server restart if required. Error: ',
            ERROR_MESSAGE()
        );
    END CATCH;

    FETCH NEXT FROM ExtraTempdbFiles INTO @Name;
END

CLOSE ExtraTempdbFiles;
DEALLOCATE ExtraTempdbFiles;

-------------------------------------------------------------------------------
-- 6. Remove WorkshopLab backup history from prior lab runs
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_delete_database_backuphistory
    @database_name = N'WorkshopLab';

-------------------------------------------------------------------------------
-- 7. Summary
-------------------------------------------------------------------------------
PRINT '';
PRINT 'Common Setup metadata applied successfully.';
PRINT 'Restart the SQL Server service now.';
PRINT 'After restart run setup/02-Validate-Setup.sql.';
