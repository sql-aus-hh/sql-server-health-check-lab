/*
    Scenario 04 - OPTIONAL ADD-ON
    Query Store Hint without changing application code

    SQL Server 2022+ / Azure SQL / Azure SQL Managed Instance

    Goal:
      Find the existing Query Store query_id and attach:
          OPTION(MAXDOP 2)

      The original query text is NOT changed.

    Note:
      The Common Lab baseline already uses instance MAXDOP = 2.
      Therefore the most important proof in this lab is that the hint is
      stored and applied to this query. If you want a visually stronger
      DOP contrast during a live demo, use MAXDOP 1 instead.
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;

-------------------------------------------------------------------------------
-- 0. Version check
-------------------------------------------------------------------------------
IF TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) < 16
    THROW 54100, 'Query Store Hints require SQL Server 2022 (16.x) or later.', 1;

-------------------------------------------------------------------------------
-- 1. Find the parameterized lookup query in Query Store
--
-- Setup.sql executed this exact statement through sp_executesql.
-- If multiple matching query_id values exist because of different context
-- settings, prefer the one with the most historical plans.
-------------------------------------------------------------------------------
DECLARE @QueryId bigint;

;WITH Candidates AS
(
    SELECT
        q.query_id,
        COUNT(DISTINCT p.plan_id) AS PlanCount
    FROM sys.query_store_query_text AS qt
    JOIN sys.query_store_query AS q
      ON q.query_text_id = qt.query_text_id
    LEFT JOIN sys.query_store_plan AS p
      ON p.query_id = q.query_id
    WHERE qt.query_sql_text LIKE N'%FROM dbo.SalesOrder%'
      AND qt.query_sql_text LIKE N'%CustomerId = @CustomerId%'
      AND qt.query_sql_text LIKE N'%OrderDate >= @StartDate%'
      AND qt.query_sql_text LIKE N'%ORDER BY OrderDate DESC%'
    GROUP BY q.query_id
)
SELECT TOP (1)
    @QueryId = query_id
FROM Candidates
ORDER BY
    PlanCount DESC,
    query_id;

IF @QueryId IS NULL
    THROW 54101, 'Target query was not found in Query Store. Run Setup.sql first.', 1;

SELECT
    @QueryId AS TargetQueryId;

-------------------------------------------------------------------------------
-- 2. Show the original Query Store text
-------------------------------------------------------------------------------
SELECT
    q.query_id,
    qt.query_sql_text
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS qt
  ON qt.query_text_id = q.query_text_id
WHERE q.query_id = @QueryId;

-------------------------------------------------------------------------------
-- 3. Attach MAXDOP 2 without changing the application query
-------------------------------------------------------------------------------
EXEC sys.sp_query_store_set_hints
    @query_id = @QueryId,
    @query_hints = N'OPTION(MAXDOP 2)';

-------------------------------------------------------------------------------
-- 4. Verify the stored Query Store Hint
-------------------------------------------------------------------------------
SELECT
    query_hint_id,
    query_id,
    query_hint_text,
    last_query_hint_failure_reason,
    last_query_hint_failure_reason_desc,
    query_hint_failure_count,
    source,
    source_desc
FROM sys.query_store_query_hints
WHERE query_id = @QueryId;

-------------------------------------------------------------------------------
-- 5. Execute the SAME application query again
--
-- Important:
--   There is still no OPTION(MAXDOP 2) in the query text below.
--   SQL Server applies the Query Store Hint by query_id.
-------------------------------------------------------------------------------
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
    @StartDate date = '2026-01-01';

EXEC sys.sp_executesql
    @LookupQuery,
    N'@CustomerId int, @StartDate date',
    @CustomerId = @CustomerId,
    @StartDate = @StartDate;

EXEC sys.sp_query_store_flush_db;

-------------------------------------------------------------------------------
-- 6. Show plans recorded for the query
--
-- QueryStoreStatementHintText in the ShowPlan XML is the important proof that
-- the hint came from Query Store rather than from the application statement.
-------------------------------------------------------------------------------
SELECT
    p.plan_id,
    p.is_forced_plan,
    p.last_compile_start_time,
    CASE
        WHEN p.query_plan LIKE N'%QueryStoreStatementHintText%'
            THEN N'Query Store Hint visible in ShowPlan XML'
        ELSE N'No Query Store Hint attribute in this stored plan'
    END AS QueryStoreHintInPlan,
    TRY_CONVERT(xml,p.query_plan) AS QueryPlan
FROM sys.query_store_plan AS p
WHERE p.query_id = @QueryId
ORDER BY p.plan_id DESC;

-------------------------------------------------------------------------------
-- 7. Optional live-demo variant
--
-- The Common Lab baseline already has instance MAXDOP = 2.
-- For a more obvious visual difference you can replace the hint with:
--
-- EXEC sys.sp_query_store_set_hints
--     @query_id = @QueryId,
--     @query_hints = N'OPTION(MAXDOP 1)';
--
-- Re-run the SAME query and compare the Actual Execution Plan.
--
-- Calling sp_query_store_set_hints again for the same query_id replaces the
-- existing Query Store Hint definition.
-------------------------------------------------------------------------------

PRINT '';
PRINT 'Query Store Hint applied.';
PRINT CONCAT('query_id = ', @QueryId);
PRINT 'Application query text was not changed.';
PRINT 'Run 08-QueryStore-Hint-Cleanup.sql when finished.';
