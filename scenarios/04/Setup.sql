/*
    SQL Server Health Check Lab
    Scenario 04 - Troubleshooting / Diagnose unter Druck
    Setup.sql

    Purpose:
      Prepare a reproducible troubleshooting lab with:
      - Blocking / Locking
      - Query Store Good/Bad plan history
      - Execution Plan analysis
      - Missing Index recommendation

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

PRINT 'Scenario 04 - preparing Troubleshooting lab...';

-------------------------------------------------------------------------------
-- 0. Preconditions
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopLab') IS NULL
    THROW 54000, 'WorkshopLab is missing. Run the Common Setup first.', 1;

-------------------------------------------------------------------------------
-- 1. Remove leftovers from previous runs
-------------------------------------------------------------------------------
IF DB_ID(N'WorkshopTrouble') IS NOT NULL
BEGIN
    ALTER DATABASE [WorkshopTrouble] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [WorkshopTrouble];
END;

-------------------------------------------------------------------------------
-- 2. Create WorkshopTrouble
-------------------------------------------------------------------------------
CREATE DATABASE [WorkshopTrouble]
ON PRIMARY
(
    NAME = N'WorkshopTrouble',
    FILENAME = N'E:\SQLData\WorkshopTrouble.mdf',
    SIZE = 512MB,
    FILEGROWTH = 256MB
)
LOG ON
(
    NAME = N'WorkshopTrouble_log',
    FILENAME = N'F:\SQLLog\WorkshopTrouble_log.ldf',
    SIZE = 256MB,
    FILEGROWTH = 256MB
);

ALTER DATABASE [WorkshopTrouble] SET RECOVERY SIMPLE;
ALTER DATABASE [WorkshopTrouble] SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE [WorkshopTrouble] SET AUTO_CLOSE OFF;
ALTER DATABASE [WorkshopTrouble] SET AUTO_SHRINK OFF;
ALTER DATABASE [WorkshopTrouble] SET QUERY_STORE = ON;
ALTER DATABASE [WorkshopTrouble]
SET QUERY_STORE
(
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = ALL,
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES = 1,
    MAX_STORAGE_SIZE_MB = 256,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30)
);

USE [WorkshopTrouble];

-------------------------------------------------------------------------------
-- 3. Blocking table
-------------------------------------------------------------------------------
CREATE TABLE dbo.Inventory
(
    InventoryId int NOT NULL
        CONSTRAINT PK_Inventory PRIMARY KEY,
    ItemCode varchar(20) NOT NULL,
    Quantity int NOT NULL,
    LastChangedUtc datetime2(0) NOT NULL
        CONSTRAINT DF_Inventory_LastChangedUtc DEFAULT (SYSUTCDATETIME())
);

;WITH n AS
(
    SELECT TOP (100)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT dbo.Inventory
(
    InventoryId,
    ItemCode,
    Quantity
)
SELECT
    n,
    CONCAT('ITEM-', RIGHT('0000' + CONVERT(varchar(10), n), 4)),
    100 + (n % 25)
FROM n;

-------------------------------------------------------------------------------
-- 4. SalesOrder table for Execution Plan / Missing Index lab
-------------------------------------------------------------------------------
CREATE TABLE dbo.SalesOrder
(
    SalesOrderId bigint IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_SalesOrder PRIMARY KEY CLUSTERED,
    CustomerId int NOT NULL,
    OrderDate date NOT NULL,
    Status tinyint NOT NULL,
    TotalAmount decimal(12,2) NOT NULL,
    SalesChannel char(2) NOT NULL,
    ReferenceNo varchar(30) NOT NULL,
    Padding char(100) NOT NULL
);

PRINT 'Loading 1,200,000 SalesOrder rows...';

;WITH E1(n) AS
(
    SELECT 1
    FROM (VALUES
        (0),(0),(0),(0),(0),(0),(0),(0),(0),(0)
    ) v(n)
),
E2(n) AS
(
    SELECT 1 FROM E1 a CROSS JOIN E1 b
),
E4(n) AS
(
    SELECT 1 FROM E2 a CROSS JOIN E2 b
),
E8(n) AS
(
    SELECT 1 FROM E4 a CROSS JOIN E4 b
),
Numbers AS
(
    SELECT TOP (1200000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM E8
)
INSERT dbo.SalesOrder
(
    CustomerId,
    OrderDate,
    Status,
    TotalAmount,
    SalesChannel,
    ReferenceNo,
    Padding
)
SELECT
    ((n - 1) % 10000) + 1,
    DATEADD(DAY, -((n - 1) % 1460), CONVERT(date,'2026-10-01')),
    CONVERT(tinyint, (n - 1) % 5),
    CONVERT(decimal(12,2), 25.00 + ((n * 17) % 500000) / 100.0),
    CASE (n % 3)
        WHEN 0 THEN 'ON'
        WHEN 1 THEN 'ST'
        ELSE 'PH'
    END,
    CONCAT('SO-', RIGHT(REPLICATE('0', 10) + CONVERT(varchar(20), n), 10)),
    REPLICATE('X',100)
FROM Numbers
OPTION (MAXDOP 1);

-------------------------------------------------------------------------------
-- 5. Create the Supporting Index and capture the GOOD plan
-------------------------------------------------------------------------------
CREATE INDEX IX_SalesOrder_Customer_OrderDate
ON dbo.SalesOrder
(
    CustomerId,
    OrderDate
)
INCLUDE
(
    Status,
    TotalAmount
);

UPDATE STATISTICS dbo.SalesOrder WITH FULLSCAN;

DECLARE @LookupQuery nvarchar(max) = N'
SELECT
    OrderDate,
    Status,
    TotalAmount
FROM dbo.SalesOrder
WHERE CustomerId = @CustomerId
  AND OrderDate >= @StartDate
ORDER BY OrderDate DESC;';

DECLARE
    @CustomerId int = 4242,
    @StartDate date = '2026-01-01',
    @i int = 1;

WHILE @i <= 8
BEGIN
    EXEC sys.sp_executesql
        @LookupQuery,
        N'@CustomerId int, @StartDate date',
        @CustomerId = @CustomerId,
        @StartDate = @StartDate;

    SET @i += 1;
END;

EXEC sys.sp_query_store_flush_db;

-------------------------------------------------------------------------------
-- 6. Simulate a change: remove the Supporting Index
-------------------------------------------------------------------------------
DROP INDEX IX_SalesOrder_Customer_OrderDate
ON dbo.SalesOrder;

-------------------------------------------------------------------------------
-- 7. Capture BAD plan with exactly the same query text
-------------------------------------------------------------------------------
SET @i = 1;

WHILE @i <= 4
BEGIN
    EXEC sys.sp_executesql
        @LookupQuery,
        N'@CustomerId int, @StartDate date',
        @CustomerId = @CustomerId,
        @StartDate = @StartDate;

    SET @i += 1;
END;

EXEC sys.sp_query_store_flush_db;

-------------------------------------------------------------------------------
-- 8. Warm one extra bad execution so missing-index DMVs are populated
-------------------------------------------------------------------------------
SELECT
    OrderDate,
    Status,
    TotalAmount
FROM dbo.SalesOrder
WHERE CustomerId = 4242
  AND OrderDate >= CONVERT(date,'2026-01-01')
ORDER BY OrderDate DESC;

PRINT '';
PRINT 'Scenario 04 setup completed.';
PRINT 'Run scenarios/04/Validate.sql.';
PRINT 'Then start with the Blocking lab or the Execution Plan lab.';
