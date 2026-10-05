# Scenario 04 - Troubleshooting / Diagnose unter Druck

Dieses Szenario bildet den vierten Workshop-Block ab:

> **Die Anwendung ist langsam. Findet die Ursache.**

Im Gegensatz zum Health Check geht es hier nicht um die allgemeine Bewertung der Umgebung, sondern um **konkrete Symptome, Hypothesen, Belege und Verifikation**.

Die Grundmethodik lautet:

```text
Observe
  ↓
Explain
  ↓
Test
  ↓
Change
  ↓
Verify
```

Scenario 04 besteht aus zwei zusammenhaengenden Troubleshooting-Tracks.

## Track A - Blocking / Locking

Der urspruengliche Workshop-Fall wird reproduziert:

- Session A oeffnet eine Transaktion gegen `dbo.Inventory`
- `TABLOCKX,HOLDLOCK` haelt einen exklusiven Tabellen-Lock
- Session B fordert `UPDLOCK,HOLDLOCK` an
- Session B wartet mit einem `LCK_M_*`-Wait
- eine Observer-Session zeigt `blocking_session_id`, Wait Type, Wait Resource und die offene Transaktion
- erst nach `ROLLBACK` in Session A loest sich das Blocking

Die Aufgabe ist **nicht**, die wartende Session als Ursache zu behandeln.

Die eigentliche Frage lautet:

> Wer blockiert wen, seit wann, wodurch und warum ist die Transaktion noch offen?

## Track B - Execution Plan / Missing Index / Query Store

Die Datenbank `WorkshopTrouble` enthaelt ausserdem eine groessere Tabelle `dbo.SalesOrder`.

Das Setup erzeugt zunaechst einen guten Zustand mit einem passenden Supporting Index und fuehrt eine reproduzierbare Lookup-Query aus.

Danach wird der Supporting Index entfernt und exakt dieselbe Query erneut ausgefuehrt.

Dadurch entstehen:

- ein **Good Plan** im Query Store
- ein **Bad Plan** im Query Store
- deutlich mehr logische Reads ohne Supporting Index
- ein Scan statt eines gezielten Seek-Zugriffs
- ein reproduzierbarer **Missing-Index-Hinweis** fuer die Lookup-Query

Damit kann nicht nur ein Screenshot eines Execution Plans betrachtet werden. Die Teilnehmer koennen denselben Query-Text vor und nach der Indexaenderung historisch im Query Store vergleichen.

## Warum zwei Tracks?

Weil Troubleshooting unterschiedliche Fragen beantworten muss.

### Symptom 1

> Eine Transaktion haengt gerade.

Hier ist Blocking die aktuelle Ursache. Ein Index-Finding aus einer anderen Query ist fuer diesen Incident nur ein Nebenbefund.

### Symptom 2

> Die Customer-Order-Suche ist seit einer Aenderung deutlich langsamer.

Hier helfen:

- Actual Execution Plan
- Estimated vs. Actual Rows
- Seek vs. Scan
- Predicate
- logical reads
- Query Store
- Plan-Historie
- Missing-Index-Empfehlung

## Execution Plans - tiefer als nur die gruene Empfehlung

Die Missing-Index-Empfehlung soll **nicht blind ausgefuehrt** werden.

Im Lab sollen mindestens folgende Fragen beantwortet werden:

1. Welcher Operator verursacht den groessten Zugriff?
2. Wird gesucht oder gescannt?
3. Welche Predicate-Spalten werden verwendet?
4. Wie unterscheiden sich Estimated und Actual Rows?
5. Wie viele logical reads entstehen?
6. Existierte frueher bereits ein passender Index?
7. Was zeigt Query Store ueber die Plan-Aenderung?
8. Passt die Missing-Index-Empfehlung zu bestehenden Indizes?
9. Welche INCLUDE-Spalten sind wirklich notwendig?
10. Wie wird der Fix nachher verifiziert?

## Ablauf

Zuerst [Setup.sql](Setup.sql) ausfuehren und danach [Validate.sql](Validate.sql).

### Blocking-Lab

In **drei SSMS-Fenstern** arbeiten:

1. [01-Blocking-Session-A.sql](01-Blocking-Session-A.sql)
2. [02-Blocking-Session-B.sql](02-Blocking-Session-B.sql)
3. [03-Blocking-Observer.sql](03-Blocking-Observer.sql)

Danach das Blocking ueber [04-Blocking-Release.sql](04-Blocking-Release.sql) freigeben.

### Execution-Plan-Lab

[05-ExecutionPlan-Bad.sql](05-ExecutionPlan-Bad.sql) mit aktiviertem **Actual Execution Plan** ausfuehren.

Danach [06-QueryStore-Compare.sql](06-QueryStore-Compare.sql), um Good und Bad Plan historisch zu vergleichen.

### Optionales Add-on - Query Store Hint ohne Codeaenderung

Im Workshop kam die Frage auf, wie einer bereits bekannten Query ein Hint mitgegeben werden kann, wenn der Anwendungscode nicht direkt geaendert werden soll.

Dafuer verwendet das Add-on **Query Store Hints**:

1. [07-QueryStore-Hint-MAXDOP.sql](07-QueryStore-Hint-MAXDOP.sql)
   - findet die passende `query_id`
   - setzt `OPTION(MAXDOP 2)` ueber `sys.sp_query_store_set_hints`
   - fuehrt denselben Anwendungstext erneut aus
   - zeigt `sys.query_store_query_hints`
   - prueft die Query-Store-Hint-Attribute im ShowPlan

2. [08-QueryStore-Hint-Cleanup.sql](08-QueryStore-Hint-Cleanup.sql)
   - entfernt den Hint wieder ueber `sys.sp_query_store_clear_hints`
   - verifiziert die Entfernung

Wichtig fuer dieses konkrete Lab: Die Common Baseline verwendet bereits `MAXDOP = 2`. Deshalb demonstriert das Add-on primaer, **wie ein Query Store Hint an eine Query gebunden und im Execution Plan nachgewiesen wird**.

Wer den DOP-Unterschied live deutlicher zeigen moechte, kann den Hint testweise auf `MAXDOP 1` setzen.

Query Store Hints sind ab SQL Server 2022 verfuegbar und erlauben Query-Level-Hints, ohne den urspruenglichen T-SQL-Text der Anwendung zu veraendern.

Microsoft Learn:
- https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints
- https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sys-sp-query-store-set-hints-transact-sql
- https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-query-hints-transact-sql
- https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sys-sp-query-store-clear-hints-transact-sql

Die Aufloesung liegt getrennt unter:

[solutions/04-troubleshooting-blocking-plans.md](../../solutions/04-troubleshooting-blocking-plans.md)

## Arbeitsraster

```text
Symptom
Beobachtung
Hypothese
Beleg
naechste Aktion
Verifikation
```

> **Warnung:** Ausschliesslich auf einer Test-/Lab-Instanz ausfuehren.
