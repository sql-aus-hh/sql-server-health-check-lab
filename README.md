# SQL Server Health Check Lab

Dieses Repository begleitet meinen Workshop **SQL Server Health Check** bei den SQLDays 2026 in Erding.

Ziel ist nicht nur, die Slides und Demo-Skripte bereitzustellen. Die Workshop-Szenarien sollen sich auf einer eigenen SQL Server Test-VM reproduzierbar nachbauen lassen:

1. Common Setup herstellen
2. ein Szenario gezielt erzeugen
3. den SQL Server analysieren
4. Ursache und Auswirkungen nachvollziehen
5. das Szenario wieder sauber zurücksetzen

> **Wichtig:** Dieses Repository ist ausschließlich für Test- und Lernumgebungen gedacht. Die Skripte können absichtlich problematische oder suboptimale Zustände erzeugen. Nicht auf produktiven SQL Servern ausführen.

## Repository-Struktur

```text
.
├── docs/
│   └── sql-days-erding-2026.md
├── setup/
│   ├── README.md
│   ├── 01-Common-Setup.sql
│   └── 02-Validate-Setup.sql
├── scenarios/
│   ├── 01/                 # Build / Setup Review
│   ├── 02/                 # Take Ownership / Recovery Readiness
│   ├── 03/                 # Health Check / Assess, Don't Assume
│   └── 04/                 # Troubleshooting / Blocking + Execution Plans
├── solutions/
│   └── README.md
└── slides/
    └── README.md
```

## Lab Base Requirements

Die vier Szenarien setzen eine vorbereitete **Test-/Lab-VM** voraus. Das Repository installiert weder Windows noch SQL Server und legt auch keine Datentraeger an.

Wenn die folgende BASE vorhanden ist, stellt das Common Setup den definierten Ausgangszustand fuer alle Szenarien her.

### Supported Lab Baseline

- Windows Server oder Windows Client als dedizierte Test-/Lab-VM
- SQL Server **2022 oder neuer**
- SQL Server **Developer Edition**
- SQL Server Agent installiert und gestartet
- SQL Server Management Studio (SSMS)
- ausfuehrender Benutzer ist Mitglied von `sysadmin`
- Berechtigung zum Neustart des SQL Server Dienstes

### Reference Environment

Die Workshop-Skripte wurden fuer folgende kleine Referenzumgebung entworfen:

```text
SQL Server 2025 Developer
2 vCPU
8 GiB RAM
```

Abweichende CPU-/RAM-Groessen koennen verwendet werden. Die Validierung zeigt sie als Information an; die festen Lab-Konfigurationswerte sind jedoch auf diese Referenzumgebung abgestimmt.

### Required Storage

Die folgenden Laufwerke muessen **vor dem Common Setup bereits existieren** und fuer den SQL Server Dienst beschreibbar sein:

```text
C:  Windows / SQL Server binaries / system databases
D:  TempDB
E:  User database data
F:  Transaction logs
G:  Backups
```

Empfohlener freier Platz fuer das Lab:

```text
D:  >= 2 GiB
E:  >= 5 GiB
F:  >= 2 GiB
G:  >= 5 GiB
```

Die Unterverzeichnisse

```text
D:\SQLTempDB
E:\SQLData
F:\SQLLog
G:\SQLBackup
```

werden vom Common Setup angelegt.

> **Wichtig:** Die Laufwerke selbst werden nicht erzeugt. Wenn `D:`, `E:`, `F:` oder `G:` fehlen, bricht das Common Setup bewusst ab.

## Start here

1. Pruefe, ob deine VM die **Lab Base Requirements** erfuellt.
2. Oeffne [setup/README.md](setup/README.md).
3. Fuehre [setup/01-Common-Setup.sql](setup/01-Common-Setup.sql) aus.
4. Starte den SQL Server Dienst neu.
5. Fuehre [setup/02-Validate-Setup.sql](setup/02-Validate-Setup.sql) aus.
6. Fahre nur fort, wenn alle relevanten Checks `PASS` liefern.
7. Oeffne danach das README des gewuenschten Szenarios.

## Ablauf

### 1. Common Setup

Im Ordner [setup](setup/) entsteht der definierte Ausgangszustand für alle Szenarien.

### 2. Szenario auswählen

Die vier Workshop-Szenarien liegen unter [scenarios](scenarios/). Jedes Szenario wird so dokumentiert, dass Setup, Validierung und später auch Cleanup nachvollziehbar bleiben.

### 3. Erst analysieren, dann Lösung ansehen

Die eigentlichen Lösungswege werden getrennt unter [solutions](solutions/) dokumentiert. So kann das Lab zunächst wie im Workshop als Troubleshooting-Übung verwendet werden.

## Nützliche Tools und Referenzen

### dbatools

[dbatools](https://dbatools.io/) ist ein PowerShell-Modul für SQL Server Administration und Automatisierung.

Besonders passend zu diesem Lab ist [Export-DbaInstance](https://dbatools.io/Export-DbaInstance/). Damit lassen sich große Teile einer SQL Server Instanz als T-SQL-Skripte exportieren, beispielsweise Logins, SQL Agent Objekte, Database Mail, Linked Servers, Serverkonfiguration und weitere Instanzobjekte.

Das ist unter anderem hilfreich für:

- Dokumentation einer Instanz
- Migrationen
- Disaster-Recovery-Vorbereitung
- Vergleich von Test- und Produktionsumgebungen
- Aufbau reproduzierbarer Testumgebungen

Bei Exporten bitte immer prüfen, ob sicherheitsrelevante Informationen enthalten sind, bevor Dateien geteilt oder in Git eingecheckt werden.

## SQLDays 2026

Hintergrund und Hinweise zum Workshop werden unter [docs/sql-days-erding-2026.md](docs/sql-days-erding-2026.md) ergänzt.

Die Slides werden nach der Aufbereitung unter [slides](slides/) veröffentlicht.

## Status

Das Common Setup und alle vier Workshop-Szenarien sind umgesetzt. Die Lab-Skripte werden weiterhin technisch verfeinert und gegen eine echte SQL-Server-Test-VM end-to-end validiert.

## Feedback

Wenn du beim Nachbauen eines Szenarios auf ein Problem stößt oder etwas unklar ist, nutze gerne die Issues dieses Repositories.
