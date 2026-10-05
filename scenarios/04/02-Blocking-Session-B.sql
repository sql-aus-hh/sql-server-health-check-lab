/*
    Scenario 04 - Blocking / Session B

    Run this in SSMS window B AFTER Session A is holding the lock.

    This statement should wait.
    While it is waiting, use a third SSMS window to run:
      03-Blocking-Observer.sql
*/

USE [WorkshopTrouble];
GO

SET NOCOUNT ON;
SET LOCK_TIMEOUT -1;
SET CONTEXT_INFO 0x534C4F54345F574149544552; -- SLOT4_WAITER

SELECT
    @@SPID AS WaitingSessionId;

SELECT
    InventoryId,
    ItemCode,
    Quantity,
    LastChangedUtc
FROM dbo.Inventory WITH (UPDLOCK,HOLDLOCK)
WHERE InventoryId = 1;

-- This line is reached only after the blocker releases its transaction.
SELECT
    N'Blocking released.' AS Result;

SET CONTEXT_INFO 0x;
