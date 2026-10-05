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
-- 3. Restore default Data / Log paths
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

-------------------------------------------------------------------------------
-- 4. Restore TempDB to D:\SQLTempDB
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

    SET @TargetPath = N'D:\SQLTempDB\' + @TempName + @Extension;

    SET @TempSql =
        N'ALTER DATABASE [tempdb] MODIFY FILE (NAME = N''' +
        REPLACE(@TempName,'''','''''') +
        N''', FILENAME = N''' +
        REPLACE(@TargetPath,'''','''''') +
        N''', FILEGROWTH = 256MB);';

    EXEC sys.sp_executesql @TempSql;

    FETCH NEXT FROM TempFiles INTO @TempName, @TempType;
END

CLOSE TempFiles;
DEALLOCATE TempFiles;

PRINT '';
PRINT 'Scenario 01 cleanup metadata applied.';
PRINT 'Restart the SQL Server service to complete the TempDB/default-path reset.';
