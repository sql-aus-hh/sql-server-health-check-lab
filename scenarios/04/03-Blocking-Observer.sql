/*
    Scenario 04 - Blocking Observer

    Run this in a third SSMS window while Session B is waiting.

    Goal:
      Identify the waiting session, head blocker, wait type,
      wait resource, open transaction and last input buffer.
*/

USE [master];
GO

SET NOCOUNT ON;

-------------------------------------------------------------------------------
-- 1. Active blocked requests
-------------------------------------------------------------------------------
SELECT
    r.session_id,
    r.blocking_session_id,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    r.open_transaction_count,
    DB_NAME(r.database_id) AS DatabaseName,
    s.login_name,
    s.host_name,
    s.program_name,
    t.text AS CurrentStatement
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
  ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0
   OR r.session_id IN
      (
          SELECT session_id
          FROM sys.dm_exec_sessions
          WHERE context_info IN
          (
              0x534C4F54345F424C4F434B4552,
              0x534C4F54345F574149544552
          )
      )
ORDER BY
    CASE WHEN r.blocking_session_id = 0 THEN 0 ELSE 1 END,
    r.session_id;

-------------------------------------------------------------------------------
-- 2. Marked lab sessions, including a sleeping head blocker
-------------------------------------------------------------------------------
SELECT
    s.session_id,
    CASE s.context_info
        WHEN 0x534C4F54345F424C4F434B4552 THEN N'BLOCKER'
        WHEN 0x534C4F54345F574149544552 THEN N'WAITER'
        ELSE N'<unknown>'
    END AS LabRole,
    s.status,
    s.open_transaction_count,
    s.login_name,
    s.host_name,
    s.program_name,
    ib.event_info AS LastSubmittedCommand
FROM sys.dm_exec_sessions AS s
OUTER APPLY sys.dm_exec_input_buffer(s.session_id,NULL) AS ib
WHERE s.context_info IN
(
    0x534C4F54345F424C4F434B4552,
    0x534C4F54345F574149544552
)
ORDER BY s.session_id;

-------------------------------------------------------------------------------
-- 3. Locks held/requested by the marked sessions
-------------------------------------------------------------------------------
SELECT
    tl.request_session_id AS session_id,
    tl.resource_type,
    tl.resource_database_id,
    DB_NAME(tl.resource_database_id) AS DatabaseName,
    tl.request_mode,
    tl.request_status,
    tl.resource_description
FROM sys.dm_tran_locks AS tl
WHERE tl.request_session_id IN
(
    SELECT session_id
    FROM sys.dm_exec_sessions
    WHERE context_info IN
    (
        0x534C4F54345F424C4F434B4552,
        0x534C4F54345F574149544552
    )
)
ORDER BY
    tl.request_session_id,
    tl.resource_type,
    tl.request_mode;

-------------------------------------------------------------------------------
-- 4. Oldest open transaction in WorkshopTrouble
-------------------------------------------------------------------------------
DBCC OPENTRAN (N'WorkshopTrouble') WITH TABLERESULTS, NO_INFOMSGS;
