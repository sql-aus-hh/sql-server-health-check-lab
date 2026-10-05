# Common Setup

Dieser Ordner stellt den **definierten Ausgangszustand** fuer alle Workshop-Szenarien her.

Das Common Setup ist bewusst eine **Lab-Baseline**. Die verwendeten Werte sind fuer eine kleine SQL Server Test-VM gedacht und stellen keine allgemeingueltigen Produktions-Best-Practices dar.

## Erwartete Lab-VM

Die Skripte gehen von folgender Umgebung aus:

- SQL Server 2025 Developer Edition
- Windows
- 2 vCPU
- 8 GiB RAM
- Systemlaufwerk `C:`
- Laufwerk `D:` fuer TempDB
- Laufwerk `E:` fuer Daten
- Laufwerk `F:` fuer Transaction Logs
- Laufwerk `G:` fuer Backups

Verwendete Verzeichnisse:

```text
D:\SQLTempDB
E:\SQLData
F:\SQLLog
G:\SQLBackup
```

## Reihenfolge

1. [01-Common-Setup.sql](01-Common-Setup.sql) ausfuehren.
2. SQL Server Dienst neu starten.
3. [02-Validate-Setup.sql](02-Validate-Setup.sql) ausfuehren.
4. Erst wenn alle Checks `PASS` liefern, ein Workshop-Szenario anwenden.

## Was das Common Setup konfiguriert

### Instanz

Die Lab-Baseline verwendet:

```text
max server memory       6144 MB
MAXDOP                  2
cost threshold          50
backup compression      ON
optimize for ad hoc     ON
```

Diese Werte dienen nur dazu, fuer alle Teilnehmer denselben Ausgangszustand herzustellen.

### Default Paths

```text
Data     E:\SQLData
Log      F:\SQLLog
Backup   G:\SQLBackup
```

### TempDB

Die Baseline verwendet exakt:

- 2 gleich konfigurierte TempDB-Datendateien
- 1 TempDB-Logdatei
- Speicherort `D:\SQLTempDB`
- Initialgroesse 256 MB je Datei
- Autogrowth 256 MB

### WorkshopLab

Die Datenbank `WorkshopLab` wird auf den separaten Data-/Log-Laufwerken angelegt.

Baseline:

- Data: `E:\SQLData\WorkshopLab.mdf`
- Log: `F:\SQLLog\WorkshopLab_log.ldf`
- Initialgroesse 256 MB je Datei
- Autogrowth 256 MB
- `AUTO_CLOSE = OFF`
- `AUTO_SHRINK = OFF`
- `PAGE_VERIFY = CHECKSUM`
- `RECOVERY = SIMPLE`

## Wiederholbarkeit

Das Skript ist fuer eine dedizierte Test-VM ausgelegt und kann erneut ausgefuehrt werden. Eine bereits vorhandene `WorkshopLab`-Datenbank wird dabei auf den definierten Zustand zurueckgesetzt.

> **Warnung:** Ausschliesslich in einer Test-/Lab-Umgebung verwenden. Das Skript veraendert Instanzkonfiguration, Default Paths, TempDB und die Datenbank `WorkshopLab`.
