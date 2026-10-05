/*
    Scenario 04 - Solution Helper
    Fix and Verify the SalesOrder lookup

    Run only after completing the Execution Plan investigation.

    Before running the lookup below:
      Enable "Include Actual Execution Plan" in SSMS (Ctrl+M).
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SalesOrder')
      AND name = N'IX_SalesOrder_Customer_OrderDate'
)
BEGIN
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
END;
GO

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

SELECT
    i.index_id,
    i.name,
    i.type_desc,
    i.is_unique,
    i.is_disabled
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID(N'dbo.SalesOrder')
ORDER BY i.index_id;
