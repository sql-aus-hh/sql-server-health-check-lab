/*
    SQL Server Health Check Lab
    Scenario 04 - Troubleshooting
    Validate.sql

    Purpose:
      Verify that the Blocking and Execution Plan labs are ready.

    PASS means the lab state is prepared as intended.
*/

USE [master];
GO

SET NOCOUNT ON;

DECLARE @Results table
(
    CheckName nvarchar(260) NOT NULL,
    ExpectedValue nvarchar(4000) NULL,
    ActualValue nvarchar(4000) NULL,
    Result varchar(10) NOT NULL
);

-------------------------------------------------------------------------------
-- 1. Database
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'WorkshopTrouble state',
    N'ONLINE',
    COALESCE(state_desc,N'<missing>'),
    CASE WHEN state_desc = N'ONLINE' THEN 'PASS' ELSE 'FAIL' END
FROM (VALUES (1)) x(dummy)
LEFT JOIN sys.databases d
  ON d.name = N'WorkshopTrouble';

DECLARE @QueryStoreState nvarchar(60);

IF DB_ID(N'WorkshopTrouble') IS NOT NULL
BEGIN
    EXEC WorkshopTrouble.sys.sp_executesql
        N'SELECT @State = actual_state_desc FROM sys.database_query_store_options;',
        N'@State nvarchar(60) OUTPUT',
        @State = @QueryStoreState OUTPUT;
END;

INSERT @Results
VALUES
(
    N'WorkshopTrouble Query Store',
    N'READ_WRITE',
    COALESCE(@QueryStoreState,N'<missing>'),
    CASE WHEN @QueryStoreState = N'READ_WRITE' THEN 'PASS' ELSE 'FAIL' END
);

-------------------------------------------------------------------------------
-- 2. Blocking objects
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'Inventory rows',
    N'100',
    CONVERT(nvarchar(50),COUNT(*)),
    CASE WHEN COUNT(*) = 100 THEN 'PASS' ELSE 'FAIL' END
FROM WorkshopTrouble.dbo.Inventory;

-------------------------------------------------------------------------------
-- 3. Execution Plan data
-------------------------------------------------------------------------------
INSERT @Results
SELECT
    N'SalesOrder rows',
    N'1200000',
    CONVERT(nvarchar(50),COUNT_BIG(*)),
    CASE WHEN COUNT_BIG(*) = 1200000 THEN 'PASS' ELSE 'FAIL' END
FROM WorkshopTrouble.dbo.SalesOrder;

INSERT @Results
SELECT
    N'Supporting index removed',
    N'ABSENT',
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM WorkshopTrouble.sys.indexes
        WHERE object_id = OBJECT_ID(N'WorkshopTrouble.dbo.SalesOrder')
          AND name = N'IX_SalesOrder_Customer_OrderDate'
    )
    THEN N'PRESENT' ELSE N'ABSENT' END,
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM WorkshopTrouble.sys.indexes
        WHERE object_id = OBJECT_ID(N'WorkshopTrouble.dbo.SalesOrder')
          AND name = N'IX_SalesOrder_Customer_OrderDate'
    )
    THEN 'FAIL' ELSE 'PASS' END;

-------------------------------------------------------------------------------
-- 4. Query Store should contain historical Good and Bad plans
-------------------------------------------------------------------------------
DECLARE @PlanCount int;

SELECT @PlanCount = COUNT(DISTINCT p.plan_id)
FROM WorkshopTrouble.sys.query_store_query_text AS qt
JOIN WorkshopTrouble.sys.query_store_query AS q
  ON q.query_text_id = qt.query_text_id
JOIN WorkshopTrouble.sys.query_store_plan AS p
  ON p.query_id = q.query_id
WHERE qt.query_sql_text LIKE N'%FROM dbo.SalesOrder%'
  AND qt.query_sql_text LIKE N'%CustomerId = @CustomerId%'
  AND qt.query_sql_text LIKE N'%ORDER BY OrderDate DESC%';

INSERT @Results
VALUES
(
    N'Query Store plans for parameterized lookup',
    N'>= 2 plans',
    CONVERT(nvarchar(50),COALESCE(@PlanCount,0)),
    CASE WHEN COALESCE(@PlanCount,0) >= 2 THEN 'PASS' ELSE 'FAIL' END
);

DECLARE
    @GoodPlanCount int,
    @BadPlanCount int,
    @BadPlanWithMissingIndex int;

SELECT
    @GoodPlanCount = SUM(CASE
        WHEN p.query_plan LIKE N'%IX_SalesOrder_Customer_OrderDate%' THEN 1 ELSE 0 END),
    @BadPlanCount = SUM(CASE
        WHEN p.query_plan NOT LIKE N'%IX_SalesOrder_Customer_OrderDate%' THEN 1 ELSE 0 END),
    @BadPlanWithMissingIndex = SUM(CASE
        WHEN p.query_plan NOT LIKE N'%IX_SalesOrder_Customer_OrderDate%'
         AND p.query_plan LIKE N'%<MissingIndexes>%' THEN 1 ELSE 0 END)
FROM WorkshopTrouble.sys.query_store_query_text AS qt
JOIN WorkshopTrouble.sys.query_store_query AS q
  ON q.query_text_id = qt.query_text_id
JOIN WorkshopTrouble.sys.query_store_plan AS p
  ON p.query_id = q.query_id
WHERE qt.query_sql_text LIKE N'%FROM dbo.SalesOrder%'
  AND qt.query_sql_text LIKE N'%CustomerId = @CustomerId%'
  AND qt.query_sql_text LIKE N'%ORDER BY OrderDate DESC%';

INSERT @Results
VALUES
(
    N'Query Store Good Plan',
    N'>= 1 plan using IX_SalesOrder_Customer_OrderDate',
    CONVERT(nvarchar(50),COALESCE(@GoodPlanCount,0)),
    CASE WHEN COALESCE(@GoodPlanCount,0) >= 1 THEN 'PASS' ELSE 'FAIL' END
);

INSERT @Results
VALUES
(
    N'Query Store Bad Plan',
    N'>= 1 plan without supporting index',
    CONVERT(nvarchar(50),COALESCE(@BadPlanCount,0)),
    CASE WHEN COALESCE(@BadPlanCount,0) >= 1 THEN 'PASS' ELSE 'FAIL' END
);

INSERT @Results
VALUES
(
    N'Bad Plan contains Missing Index hint',
    N'>= 1 MissingIndexes element',
    CONVERT(nvarchar(50),COALESCE(@BadPlanWithMissingIndex,0)),
    CASE WHEN COALESCE(@BadPlanWithMissingIndex,0) >= 1 THEN 'PASS' ELSE 'FAIL' END
);

-------------------------------------------------------------------------------
-- 5. Missing Index recommendation
-------------------------------------------------------------------------------
DECLARE @MissingIndexCount int;

SELECT @MissingIndexCount = COUNT(*)
FROM sys.dm_db_missing_index_details
WHERE database_id = DB_ID(N'WorkshopTrouble')
  AND object_id = OBJECT_ID(N'WorkshopTrouble.dbo.SalesOrder');

INSERT @Results
VALUES
(
    N'Missing-index recommendation for SalesOrder',
    N'>= 1',
    CONVERT(nvarchar(50),COALESCE(@MissingIndexCount,0)),
    CASE WHEN COALESCE(@MissingIndexCount,0) >= 1 THEN 'PASS' ELSE 'FAIL' END
);

-------------------------------------------------------------------------------
-- 6. No blocking sessions should already be running
-------------------------------------------------------------------------------
DECLARE @MarkedSessions int;

SELECT @MarkedSessions = COUNT(*)
FROM sys.dm_exec_sessions
WHERE session_id <> @@SPID
  AND context_info IN
  (
      0x534C4F54345F424C4F434B4552,
      0x534C4F54345F574149544552
  );

INSERT @Results
VALUES
(
    N'Blocking demo sessions before exercise',
    N'0',
    CONVERT(nvarchar(50),@MarkedSessions),
    CASE WHEN @MarkedSessions = 0 THEN 'PASS' ELSE 'FAIL' END
);

-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------
SELECT
    CheckName,
    ExpectedValue,
    ActualValue,
    Result
FROM @Results
ORDER BY
    CASE WHEN Result = 'FAIL' THEN 0 ELSE 1 END,
    CheckName;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = 'FAIL')
BEGIN
    PRINT '';
    PRINT 'Scenario 04 validation FAILED.';
    PRINT 'Resolve the failed preparation checks before starting the lab.';
END
ELSE
BEGIN
    PRINT '';
    PRINT 'Scenario 04 validation PASSED.';
    PRINT 'Blocking and Execution Plan labs are ready.';
END;
