/*
    Scenario 04 - Execution Plan / Missing Index

    Before running:
      In SSMS enable "Include Actual Execution Plan" (Ctrl+M).

    Goal:
      Do not jump directly to the green Missing Index recommendation.
      Inspect the whole plan and the runtime evidence.
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    OrderDate,
    Status,
    TotalAmount
FROM dbo.SalesOrder
WHERE CustomerId = 4242
  AND OrderDate >= CONVERT(date,'2026-01-01')
ORDER BY OrderDate DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

/*
    Questions for the plan:

    1. Which access operator is used on dbo.SalesOrder?
    2. Seek or Scan?
    3. What are Estimated Rows vs. Actual Rows?
    4. Which predicate is applied?
    5. How many logical reads were reported?
    6. Is a Missing Index recommendation shown?
    7. Which key columns does SQL Server propose?
    8. Which INCLUDE columns are proposed?
    9. Does a similar index already exist?
   10. Is the recommendation the cause, or only a tuning opportunity?
*/

SELECT
    i.index_id,
    i.name,
    i.type_desc,
    i.is_unique,
    i.is_disabled
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID(N'dbo.SalesOrder')
ORDER BY i.index_id;
