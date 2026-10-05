/*
    SQL Server Health Check Lab
    Scenario 01 - Build / Setup Review
    Setup.sql

    Purpose:
      Reproduce the intentionally suboptimal configuration used in the
      SQLDays 2026 workshop.

    WARNING:
      LAB / TEST SYSTEMS ONLY.

    Expected environment:
      SQL Server 2025 Developer
      2 vCPU / 8 GiB RAM
      WorkshopLab database exists
      D:\SQLTempDB
      E:\SQLData
      F:\SQLLog
      G:\SQLBackup

    IMPORTANT:
      Restart the SQL Server service after this script before running Validate.sql.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT 'Scenario 01 - applying instance configuration...';

IF (SELECT COUNT(*) FROM tempdb.sys.database_files) <> 3
    THROW 51002, 'Scenario 01 expects exactly three TempDB files (two data files plus one log file). Run the Common Setup first.', 1;

-------------------------------------------------------------------------------
-- 1. Instance configuration
-------------------------------------------------------------------------------
EXEC sys.sp_configure N'show advanced options', 1;
RECONFIGURE;

EXEC sys.sp_configure N'max server memory (MB)', 2147483647;
EXEC sys.sp_configure N'max degree of parallelism', 0;
EXEC sys.sp_configure N'cost threshold for parallelism', 5;
EXEC sys.sp_configure N'backup compression default', 0;
EXEC sys.sp_configure N'optimize for ad hoc workloads', 0;
RECONFIGURE;

-------------------------------------------------------------------------------
-- 2. WorkshopLab database options
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab') IS NULL
    THROW 51001, 'WorkshopLab does not exist. Run the Common Setup first.', 1;

ALTER DATABASE [WorkshopLab] SET AUTO_CLOSE OFF;
ALTER DATABASE [WorkshopLab] SET AUTO_SHRINK ON;
ALTER DATABASE [WorkshopLab] SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE [WorkshopLab] SET RECOVERY FULL;

-------------------------------------------------------------------------------
-- 3. WorkshopLab file growth: deliberately tiny 1 MB increments
-------------------------------------------------------------------------------
DECLARE @sql nvarchar(max) = N'';

SELECT @sql +=
    N'ALTER DATABASE [WorkshopLab] MODIFY FILE (NAME = N''' +
    REPLACE(name,'''','''''') +
    N''', FILEGROWTH = 1MB);' + CHAR(13) + CHAR(10)
FROM sys.master_files
WHERE database_id = DB_ID(N'WorkshopLab');

EXEC sys.sp_executesql @sql;

-------------------------------------------------------------------------------
-- 4. Remove backup history for WorkshopLab
--    This makes the FULL-without-backup-chain finding reproducible.
-------------------------------------------------------------------------------
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'WorkshopLab';

-------------------------------------------------------------------------------
-- 5. Default Data / Log paths: point them back to the system drive.
--
-- We deliberately reuse the directories of master.mdf and mastlog.ldf.
-- On the workshop VM these are on C: and already exist with valid SQL Server
-- service permissions.
-------------------------------------------------------------------------------
DECLARE @MasterDataPath nvarchar(4000);
DECLARE @MasterLogPath  nvarchar(4000);

SELECT @MasterDataPath =
       LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
FROM sys.master_files
WHERE database_id = 1 AND file_id = 1;

SELECT @MasterLogPath =
       LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
FROM sys.master_files
WHERE database_id = 1 AND type_desc = N'LOG';

EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'DefaultData',
    REG_SZ,
    @MasterDataPath;

EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'DefaultLog',
    REG_SZ,
    @MasterLogPath;

-------------------------------------------------------------------------------
-- 6. TempDB: move files to the same system-drive directories and configure
--    deliberately small sizes / growth.
--
-- The workshop VM contains the normal TempDB files created by setup.
-- We preserve the existing logical file count and only change path, size
-- target and growth.
-------------------------------------------------------------------------------
DECLARE
    @TempName sysname,
    @TempType int,
    @TargetPath nvarchar(4000),
    @Extension nvarchar(10),
    @TempSql nvarchar(max);

DECLARE TempFiles CURSOR LOCAL FAST_FORWARD FOR
SELECT name, type
FROM tempdb.sys.database_files
ORDER BY file_id;

OPEN TempFiles;
FETCH NEXT FROM TempFiles INTO @TempName, @TempType;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Extension =
        CASE
            WHEN @TempType = 1 THEN N'.ldf'
            WHEN @TempName = N'tempdev' THEN N'.mdf'
            ELSE N'.ndf'
        END;

    SET @TargetPath =
        CASE WHEN @TempType = 1 THEN @MasterLogPath ELSE @MasterDataPath END
        + @TempName + @Extension;

    SET @TempSql =
        N'ALTER DATABASE [tempdb] MODIFY FILE (NAME = N''' +
        REPLACE(@TempName,'''','''''') +
        N''', FILENAME = N''' +
        REPLACE(@TargetPath,'''','''''') +
        N''', FILEGROWTH = 1MB);';

    EXEC sys.sp_executesql @TempSql;

    FETCH NEXT FROM TempFiles INTO @TempName, @TempType;
END

CLOSE TempFiles;
DEALLOCATE TempFiles;

-------------------------------------------------------------------------------
-- 7. Best-effort TempDB shrink toward the workshop size.
--    System allocations can prevent an exact 8 MB shrink while online.
--    After restart SQL Server will recreate the files using the configured
--    metadata where possible.
-------------------------------------------------------------------------------
DECLARE @ShrinkName sysname;

DECLARE ShrinkFiles CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM tempdb.sys.database_files;

OPEN ShrinkFiles;
FETCH NEXT FROM ShrinkFiles INTO @ShrinkName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @TempSql = N'USE [tempdb]; DBCC SHRINKFILE (N''' +
                       REPLACE(@ShrinkName,'''','''''') +
                       N''', 8) WITH NO_INFOMSGS;';
        EXEC sys.sp_executesql @TempSql;

        SET @TempSql = N'ALTER DATABASE [tempdb] MODIFY FILE (NAME = N''' +
                       REPLACE(@ShrinkName,'''','''''') +
                       N''', SIZE = 8MB, FILEGROWTH = 1MB);';
        EXEC sys.sp_executesql @TempSql;
    END TRY
    BEGIN CATCH
        PRINT CONCAT('TempDB shrink skipped for ', @ShrinkName, ': ', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM ShrinkFiles INTO @ShrinkName;
END

CLOSE ShrinkFiles;
DEALLOCATE ShrinkFiles;

PRINT '';
PRINT 'Scenario 01 setup completed.';
PRINT 'Restart the SQL Server service now.';
PRINT 'Then run scenarios/01/Validate.sql.';
