/*
    Scenario 04 - OPTIONAL ADD-ON
    Remove Query Store Hint

    Removes all Query Store Hints associated with the target query_id.
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;

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
    THROW 54110, 'Target query was not found in Query Store.', 1;

-------------------------------------------------------------------------------
-- Show current hint before removal
-------------------------------------------------------------------------------
SELECT
    query_hint_id,
    query_id,
    query_hint_text,
    last_query_hint_failure_reason,
    last_query_hint_failure_reason_desc,
    query_hint_failure_count,
    source_desc
FROM sys.query_store_query_hints
WHERE query_id = @QueryId;

-------------------------------------------------------------------------------
-- Remove the Query Store Hint
-------------------------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM sys.query_store_query_hints
    WHERE query_id = @QueryId
)
BEGIN
    EXEC sys.sp_query_store_clear_hints
        @query_id = @QueryId;
END;

-------------------------------------------------------------------------------
-- Verify removal
-------------------------------------------------------------------------------
SELECT
    query_hint_id,
    query_id,
    query_hint_text,
    source_desc
FROM sys.query_store_query_hints
WHERE query_id = @QueryId;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.query_store_query_hints
    WHERE query_id = @QueryId
)
BEGIN
    PRINT CONCAT('Query Store Hint removed successfully for query_id ', @QueryId, '.');
END
ELSE
BEGIN
    THROW 54111, 'Query Store Hint still exists after cleanup.', 1;
END;
