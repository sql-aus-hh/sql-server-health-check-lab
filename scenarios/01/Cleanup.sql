/*
    SQL Server Health Check Lab
    Scenario 01 - Build / Setup Review
    Cleanup.sql

    Restores the defined baseline for the SQLDays lab VM.

    WARNING:
      LAB / TEST SYSTEMS ONLY.

    A SQL Server service restart is required after this script because
    TempDB paths and instance default paths are changed.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

-------------------------------------------------------------------------------
-- 1. Instance baseline for this lab VM (2 vCPU / 8 GiB RAM)
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
-- 2. WorkshopLab baseline
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopLab] SET AUTO_CLOSE OFF;
    ALTER DATABASE [WorkshopLab] SET AUTO_SHRINK OFF;
    ALTER DATABASE [WorkshopLab] SET PAGE_VERIFY CHECKSUM;
    ALTER DATABASE [WorkshopLab] SET RECOVERY SIMPLE;

    DECLARE @sql nvarchar(max) = N'';

    SELECT @sql +=
        N'ALTER DATABASE [WorkshopLab] MODIFY FILE (NAME = N''' +
        REPLACE(name,'''','''''') +
        N''', FILEGROWTH = 256MB);' + CHAR(13) + CHAR(10)
    FROM sys.master_files
    WHERE database_id = DB_ID(N'WorkshopLab');

    EXEC sys.sp_executesql @sql;
END

-------------------------------------------------------------------------------
-- 3. Restore instance default paths
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
-- 4. Restore TempDB exactly to the Common Setup baseline
-------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM tempdb.sys.database_files
    WHERE name = N'tempdev'
      AND type = 0
)
    THROW 51010, 'Expected TempDB file tempdev is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM tempdb.sys.database_files
    WHERE name = N'tempdev2'
      AND type = 0
)
    THROW 51011, 'Expected TempDB file tempdev2 is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM tempdb.sys.database_files
    WHERE name = N'templog'
      AND type = 1
)
    THROW 51012, 'Expected TempDB file templog is missing.', 1;

ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'tempdev',
    FILENAME = N'D:\SQLTempDB\tempdb.mdf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'tempdev2',
    FILENAME = N'D:\SQLTempDB\tempdb2.ndf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

ALTER DATABASE [tempdb]
MODIFY FILE
(
    NAME = N'templog',
    FILENAME = N'D:\SQLTempDB\templog.ldf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

-------------------------------------------------------------------------------
-- 5. Keep WorkshopLab backup history deterministic
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_delete_database_backuphistory
    @database_name = N'WorkshopLab';

PRINT '';
PRINT 'Scenario 01 cleanup metadata applied.';
PRINT 'Restart the SQL Server service to complete the TempDB/default-path reset.';
