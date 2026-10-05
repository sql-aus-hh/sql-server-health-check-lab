/*
    Scenario 04 - Blocking Release

    Run this in the SAME SSMS window as 01-Blocking-Session-A.sql.
*/

USE [WorkshopTrouble];
GO

IF @@TRANCOUNT > 0
BEGIN
    ROLLBACK TRAN;
    PRINT 'Blocking transaction rolled back.';
END
ELSE
BEGIN
    PRINT 'No open transaction found in this session.';
END;

SET CONTEXT_INFO 0x;

SELECT
    @@SPID AS SessionId,
    @@TRANCOUNT AS OpenTransactionCount;
