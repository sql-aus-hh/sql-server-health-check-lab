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
│   ├── 01/
│   │   └── README.md
│   ├── 02/
│   │   └── README.md
│   ├── 03/
│   │   └── README.md
│   └── 04/
│       └── README.md
├── solutions/
│   └── README.md
└── slides/
    └── README.md
```

## Voraussetzungen

Die konkreten Voraussetzungen werden mit den finalen Workshop-Skripten dokumentiert. Geplant ist eine eigenständige SQL Server Test-VM, auf der das Common Setup und anschließend jeweils eines der vier Szenarien ausgeführt werden kann.

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

Das Repository befindet sich im Aufbau. Das Common Setup und Scenario 01 sind bereits umgesetzt; die weiteren drei Workshop-Szenarien werden schrittweise ergänzt.

## Feedback

Wenn du beim Nachbauen eines Szenarios auf ein Problem stößt oder etwas unklar ist, nutze gerne die Issues dieses Repositories.
