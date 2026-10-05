# Scenario 03 - Health Check / Assess, Don't Assume

Dieses Szenario bildet den dritten Workshop-Block ab:

> **Ist diese Umgebung gesund genug fuer den Betrieb?**

Anders als in Scenario 01 geht es nicht darum, eine Baseline herzustellen. Anders als in Scenario 02 geht es nicht primaer um eine konkrete Recovery-Aufgabe.

Die Aufgabe ist eine **fachliche Bewertung einer bestehenden Umgebung mit gemischten Findings**.

## Auftrag und Kontext

Die Applikationsbetreuung bittet um einen Health Check. Es gibt **keinen akuten Incident**.

Die Frage lautet:

> Gibt es relevante betriebliche Risiken, die wir zeitnah adressieren sollten?

### HealthCheckApp

- produktionskritische Anwendung
- RPO: 15 Minuten
- RTO: 60 Minuten
- regulaere Nutzung tagsueber
- keine aktuell gemeldeten Performanceprobleme

### LegacyReporting

- internes Reporting
- nicht produktionskritisch
- kann aus einem Quellsystem neu aufgebaut werden
- Wiederaufbau innerhalb von etwa vier Stunden akzeptabel
- kein formales Point-in-Time-RPO

Dieser Kontext ist Teil der Uebung. Derselbe technische Befund kann je nach Datenbank unterschiedlich bewertet werden.

## Lernziel

Nicht moeglichst viele Abweichungen finden.

Stattdessen fuer jedes relevante Finding entscheiden:

1. Was beobachte ich?
2. Ist es nur eine Abweichung, ein Risiko oder bereits kritisch?
3. Welche Information fehlt mir fuer eine belastbare Bewertung?
4. Welche konkrete Empfehlung ergibt sich daraus?

Das Ergebnis sollte mindestens diese vier Spalten enthalten:

```text
Finding | Bewertung | Begruendung | Empfehlung
```

## Vorbereitete Findings

Das Szenario enthaelt bewusst eine Mischung aus eindeutigen Risiken, kontextabhaengigen Findings und korrekten Einstellungen.

Unter anderem:

- `MAXDOP = 0` auf der kleinen Lab-VM
- sinnvoll begrenztes `max server memory`
- `cost threshold for parallelism = 50`
- Backup Compression aktiviert
- unterschiedliche TempDB-Growth-Werte
- `HealthCheckApp` im Recovery Model FULL
- ein Full Backup, aber keine Log Backups trotz RPO 15 Minuten
- eine zusaetzliche Datendatei von `HealthCheckApp` auf dem Systemlaufwerk
- Compatibility Level 150
- Query Store deaktiviert
- `PAGE_VERIFY = CHECKSUM` und `AUTO_SHRINK = OFF` bei der Hauptdatenbank
- `LegacyReporting` mit `AUTO_SHRINK = ON`
- `LegacyReporting` mit `PAGE_VERIFY = TORN_PAGE_DETECTION`
- Prozent-Autogrowth bei `LegacyReporting`
- keine Backup-Historie fuer `LegacyReporting`
- ein erfolgreicher taeglicher Full-Backup-Job fuer `HealthCheckApp`
- ein deaktivierter CHECKDB-Job
- ein Maintenance-Job, der `DBCC SHRINKDATABASE` enthaelt
- ein Operator mit einer nicht produktionsfaehigen Beispieladresse
- `TRUSTWORTHY = ON` bei `LegacyReporting`

Nicht jedes Finding ist gleich wichtig.

Und nicht jede technisch ungewoehnliche Einstellung muss geaendert werden.

## Wait Statistics

Wait Statistics gehoeren zum Health Check, werden in diesem Lab aber **nicht kuenstlich auf einen Zielwert manipuliert**.

Die Werte aus `sys.dm_os_wait_stats` stammen aus dem realen Lauf der Testinstanz und sollen genau deshalb nur im Kontext betrachtet werden.

Das entspricht der Kernaussage des Workshops:

> Waits sind Hinweise, keine fertigen Ursachen.

## Dateien

- [Setup.sql](Setup.sql) erzeugt die gemischte Health-Check-Umgebung.
- [Validate.sql](Validate.sql) prueft nur, ob das Lab wie vorgesehen vorbereitet wurde.
- [Cleanup.sql](Cleanup.sql) entfernt die Scenario-03-Artefakte und stellt die Common Baseline wieder her.
- Die Aufloesung liegt unter [solutions/03-health-check-assess-dont-assume.md](../../solutions/03-health-check-assess-dont-assume.md).

## Voraussetzung

> **Prerequisite: Common Setup successfully validated.**

Siehe [Common Setup](../../setup/).

> **Warnung:** Ausschliesslich auf einer Test-/Lab-Instanz ausfuehren.
