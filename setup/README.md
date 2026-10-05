# Common Setup

Dieser Ordner stellt den **definierten Ausgangszustand** fuer alle Workshop-Szenarien her.

Das Common Setup ist bewusst eine **Lab-Baseline**. Die verwendeten Werte sind fuer eine kleine SQL Server Test-VM gedacht und stellen keine allgemeingueltigen Produktions-Best-Practices dar.

## Start here

### 1. BASE pruefen

Vor dem ersten Skript muss folgende Basis vorhanden sein:

- Windows Test-/Lab-VM
- SQL Server **2022 oder neuer**
- Developer Edition
- SQL Server Agent installiert und gestartet
- SSMS
- `sysadmin`-Berechtigung
- Berechtigung zum Neustart des SQL Server Dienstes
- vorhandene und fuer SQL Server beschreibbare Laufwerke `D:`, `E:`, `F:` und `G:`

Referenzumgebung:

```text
SQL Server 2025 Developer
2 vCPU
8 GiB RAM
```

Storage-Rollen:

```text
C:  Windows / SQL Server binaries / system databases
D:  TempDB
E:  User database data
F:  Transaction logs
G:  Backups
```

Die folgenden Unterverzeichnisse muessen nicht vorher angelegt werden. Das Common Setup erzeugt sie:

```text
D:\SQLTempDB
E:\SQLData
F:\SQLLog
G:\SQLBackup
```

### 2. Common Setup ausfuehren

[01-Common-Setup.sql](01-Common-Setup.sql)

Das Skript:

- prueft die benoetigten Laufwerke
- erstellt die Lab-Verzeichnisse
- setzt die definierte Instanz-Baseline
- konfiguriert Default Data/Log/Backup Paths
- erstellt `WorkshopLab`
- konfiguriert TempDB

### 3. SQL Server Dienst neu starten

Der Neustart ist notwendig, damit insbesondere die TempDB-Dateipfade vollstaendig uebernommen werden.

### 4. Baseline validieren

[02-Validate-Setup.sql](02-Validate-Setup.sql)

Nur wenn alle relevanten Checks `PASS` liefern, mit einem Szenario fortfahren.

### 5. Szenario starten

Danach eines der vier Scenario-READMEs oeffnen. Jedes Szenario setzt nur noch voraus:

> **Prerequisite: Common Setup successfully validated.**

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
