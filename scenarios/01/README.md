# Scenario 01 - Build / Setup Review

Dieses Szenario bildet den ersten Workshop-Block ab: **Ein SQL Server ist installiert und laeuft. Aber ist das Setup wirklich sinnvoll?**

Es gibt hier bewusst nicht den einen spektakulaeren Fehler. Stattdessen enthaelt die Instanz mehrere typische Default- oder Setup-Einstellungen, die bei einem ersten Health Check auffallen sollten.

## Lernziel

Analysiere die Instanz zunaechst, ohne sofort Einstellungen zu veraendern.

Die zentrale Frage lautet:

> Welche Einstellungen sind tatsaechlich problematisch, welche sind nur auffaellig und welche sind bereits korrekt?

## Erwartete Findings

Im vorbereiteten Szenario sollten unter anderem folgende Punkte auffallen:

- `max server memory (MB)` steht auf dem Default und ist damit praktisch unbegrenzt.
- `max degree of parallelism` steht auf `0`.
- `cost threshold for parallelism` steht auf `5`.
- `backup compression default` steht auf `0`.
- `optimize for ad hoc workloads` steht auf `0`.
- TempDB liegt auf dem Systemlaufwerk und verwendet kleine Dateien / kleine Growth-Werte.
- Default Data und Default Log zeigen auf das Systemlaufwerk.
- Die Daten- und Logdateien von `WorkshopLab` wachsen in 1-MB-Schritten.
- `AUTO_SHRINK` ist fuer `WorkshopLab` aktiviert.
- `WorkshopLab` verwendet Recovery Model `FULL`, ohne dass eine passende Backup-Historie vorhanden ist.

Nicht alles soll schlecht sein:

- `PAGE_VERIFY = CHECKSUM` ist korrekt.
- `AUTO_CLOSE = OFF` ist korrekt.

## Dateien

- [Setup.sql](Setup.sql) erzeugt den Workshop-Zustand.
- [Validate.sql](Validate.sql) prueft, ob die erwarteten Findings vorhanden sind.
- [Cleanup.sql](Cleanup.sql) setzt die Lab-VM auf den definierten Baseline-Zustand zurueck.
- Die Aufloesung liegt getrennt unter [solutions/01-build-setup-review.md](../../solutions/01-build-setup-review.md).

## Voraussetzungen

Dieses Szenario setzt das Common Setup des Repositories voraus.

Erwartete Lab-Struktur:

- SQL Server 2025 Developer
- 2 vCPU
- 8 GiB RAM
- `D:\SQLTempDB`
- `E:\SQLData`
- `F:\SQLLog`
- `G:\SQLBackup`
- Datenbank `WorkshopLab`

## Wichtiger Hinweis zu TempDB und Default Paths

Ein Teil dieses Szenarios veraendert Dateipfade. SQL Server uebernimmt TempDB-Dateipfade erst beim naechsten Start der Instanz vollstaendig.

Nach `Setup.sql` ist deshalb ein **Neustart des SQL-Server-Dienstes** vorgesehen. Danach `Validate.sql` ausfuehren.

> Ausschliesslich auf einer Test-VM ausfuehren.
