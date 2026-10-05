/*
    Scenario 04 - Blocking / Session A

    Run this in SSMS window A.
    Leave this session open after the script finishes.

    This session intentionally leaves a transaction open and holds
    an exclusive table lock on dbo.Inventory.
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;
SET CONTEXT_INFO 0x534C4F54345F424C4F434B4552; -- SLOT4_BLOCKER

BEGIN TRAN;

SELECT
    InventoryId,
    ItemCode,
    Quantity,
    LastChangedUtc
FROM dbo.Inventory WITH (TABLOCKX,HOLDLOCK)
WHERE InventoryId BETWEEN 1 AND 10;

SELECT
    @@SPID AS BlockerSessionId,
    @@TRANCOUNT AS OpenTransactionCount,
    N'Leave this transaction open. Now run 02-Blocking-Session-B.sql in another SSMS window.' AS NextStep;

-- Intentionally no COMMIT / ROLLBACK here.
