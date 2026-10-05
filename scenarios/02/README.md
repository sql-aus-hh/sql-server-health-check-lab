# Scenario 02 - Take Ownership / Recovery Readiness

Der SQL Server laeuft. Die Jobs sehen auf den ersten Blick ordentlich aus. Die eigentliche Frage lautet aber:

> **Koennt ihr diesen Server morgen wirklich verantworten?**

Scenario 02 bildet den Workshop-Block **Take ownership** ab. Im Mittelpunkt stehen nicht Setup-Defaults, sondern Betriebsfaehigkeit, Backup-Historie, SQL Agent, Recovery und die Frage, ob ein scheinbar gruener Betrieb im Ernstfall wirklich belastbar ist.

## Lernziel

Bewerte die vorbereitete Umgebung wie bei einer Betriebsuebernahme.

Nicht sofort alles aendern. Zuerst verstehen:

- Welche Datenbanken gehoeren zum System?
- Was wird gesichert?
- Was wird **nicht** gesichert?
- Welche Backup-Kette ist fuer einen konkreten Recovery-Zeitpunkt geeignet?
- Ist ein gruener SQL-Agent-Job bereits ein Recovery-Nachweis?
- Wer wuerde bei einem Fehler informiert?
- Kann der geforderte Datenstand auf einer separaten Datenbank wiederhergestellt und geprueft werden?

## Vorbereitete Umgebung

Das Szenario erzeugt zwei Datenbanken:

- `WorkshopOps`
- `WorkshopOps_Audit`

`WorkshopOps` verwendet das Recovery Model `FULL` und besitzt eine kontrollierte Backup-Kette.

`WorkshopOps_Audit` gehoert fachlich zur Umgebung, wird vom vorbereiteten Backup-Job aber bewusst **nicht** erfasst.

## Kontrollierte Backup-Kette

Unter `G:\SQLBackup\Slot2` werden erzeugt:

```text
WorkshopOps_FULL.bak
WorkshopOps_LOG_01.trn
WorkshopOps_LOG_02.trn
WorkshopOps_LOG_03.trn
WorkshopOps_JOB_COPYONLY.bak
```

Die Datenbank enthaelt Marker, mit denen der gewuenschte Recovery-Zustand eindeutig nachvollzogen werden kann:

```text
FULL_BASELINE
LOG_01_APPLIED
SLOT2_TARGET
AFTER_TARGET_DO_NOT_INCLUDE
```

Der geforderte Zielzustand ist **SLOT2_TARGET**.

Dazu gehoert die Bestellung:

```text
OPS-1201
```

Der spaetere Zustand

```text
AFTER_TARGET_DO_NOT_INCLUDE
OPS-1301
```

darf in der wiederhergestellten Zieldatenbank nicht enthalten sein.

## SQL Agent

Das Setup erzeugt einen erfolgreichen SQL-Agent-Backup-Job:

```text
SQLDays - Slot2 - WorkshopOps Backup
```

Der Job erstellt ein `COPY_ONLY` Full Backup von `WorkshopOps`.

Absichtlich auffaellig:

- `WorkshopOps_Audit` wird nicht gesichert.
- Ein Operator ist eingetragen, verwendet aber eine nicht produktionsfaehige Beispieladresse.
- Der erfolgreiche Job beweist nicht, dass der geforderte Recovery-Zustand erreichbar ist.

## Arbeitsauftrag

1. Verschaffe dir einen Ueberblick ueber Datenbanken, Jobs und Backup-Historie.
2. Bewerte die vorhandene Backup-Abdeckung.
3. Identifiziere die fuer `SLOT2_TARGET` geeignete Backup-Kette.
4. Stelle den Zielzustand als neue Datenbank `WorkshopLab_Restore` wieder her.
5. Pruefe fachlich anhand von `dbo.LabMarker` und `dbo.Orders`, ob der korrekte Zustand erreicht wurde.
6. Fuehre anschliessend `DBCC CHECKDB` gegen die Restore-Datenbank aus.
7. Dokumentiere Findings als:
   - Finding
   - Risiko
   - offene Frage
   - naechste Aktion

## Dateien

- [Setup.sql](Setup.sql) erzeugt das Szenario.
- [Validate.sql](Validate.sql) prueft, ob die vorbereitete Ausgangslage korrekt hergestellt wurde.
- [Cleanup.sql](Cleanup.sql) entfernt die Scenario-02-Objekte wieder.
- Die Aufloesung liegt getrennt unter [solutions/02-take-ownership-recovery.md](../../solutions/02-take-ownership-recovery.md).

## Voraussetzung

Vorher das [Common Setup](../../setup/) ausfuehren und erfolgreich validieren.

> **Warnung:** Ausschliesslich auf einer Test-/Lab-Instanz ausfuehren.
