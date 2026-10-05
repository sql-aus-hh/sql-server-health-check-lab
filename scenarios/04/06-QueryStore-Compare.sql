/*
    Scenario 04 - Query Store Good vs. Bad Plan

    The Setup executed the same parameterized lookup:
      - first with IX_SalesOrder_Customer_OrderDate
      - then after the index was removed

    Query Store should therefore retain both historical plans.
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;

;WITH TargetQuery AS
(
    SELECT DISTINCT
        q.query_id,
        qt.query_sql_text
    FROM sys.query_store_query_text AS qt
    JOIN sys.query_store_query AS q
      ON q.query_text_id = qt.query_text_id
    WHERE qt.query_sql_text LIKE N'%FROM dbo.SalesOrder%'
      AND qt.query_sql_text LIKE N'%CustomerId = @CustomerId%'
      AND qt.query_sql_text LIKE N'%ORDER BY OrderDate DESC%'
),
RuntimeByPlan AS
(
    SELECT
        rs.plan_id,
        SUM(rs.count_executions) AS Executions,
        SUM(rs.avg_duration * rs.count_executions)
            / NULLIF(SUM(rs.count_executions),0) / 1000.0 AS AvgDurationMs,
        SUM(rs.avg_cpu_time * rs.count_executions)
            / NULLIF(SUM(rs.count_executions),0) / 1000.0 AS AvgCpuMs,
        SUM(rs.avg_logical_io_reads * rs.count_executions)
            / NULLIF(SUM(rs.count_executions),0) AS AvgLogicalReads
    FROM sys.query_store_runtime_stats AS rs
    GROUP BY rs.plan_id
)
SELECT
    tq.query_id,
    p.plan_id,
    CASE
        WHEN p.query_plan LIKE N'%IX_SalesOrder_Customer_OrderDate%'
            THEN N'GOOD - Supporting Index present'
        ELSE N'BAD / post-index-removal'
    END AS PlanClassification,
    rbp.Executions,
    CAST(rbp.AvgDurationMs AS decimal(18,2)) AS AvgDurationMs,
    CAST(rbp.AvgCpuMs AS decimal(18,2)) AS AvgCpuMs,
    CAST(rbp.AvgLogicalReads AS decimal(18,2)) AS AvgLogicalReads,
    p.last_compile_start_time,
    TRY_CONVERT(xml,p.query_plan) AS QueryPlan
FROM TargetQuery AS tq
JOIN sys.query_store_plan AS p
  ON p.query_id = tq.query_id
LEFT JOIN RuntimeByPlan AS rbp
  ON rbp.plan_id = p.plan_id
ORDER BY p.plan_id;

-------------------------------------------------------------------------------
-- Missing Index DMV evidence for the current state
-------------------------------------------------------------------------------
SELECT
    mid.index_handle,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.user_seeks,
    migs.user_scans,
    CAST(
        migs.avg_total_user_cost
        * migs.avg_user_impact
        * (migs.user_seeks + migs.user_scans)
        AS decimal(18,2)
    ) AS RelativeImprovementSignal
FROM sys.dm_db_missing_index_details AS mid
JOIN sys.dm_db_missing_index_groups AS mig
  ON mig.index_handle = mid.index_handle
JOIN sys.dm_db_missing_index_group_stats AS migs
  ON migs.group_handle = mig.index_group_handle
WHERE mid.database_id = DB_ID()
  AND mid.object_id = OBJECT_ID(N'dbo.SalesOrder')
ORDER BY RelativeImprovementSignal DESC;
