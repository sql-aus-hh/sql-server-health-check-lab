# Solution 03 - Health Check / Assess, Don't Assume

Scenario 03 soll nicht zeigen, wie viele rote Werte man auf einem SQL Server finden kann.

Es soll zeigen, wie aus technischen Beobachtungen eine **priorisierte fachliche Bewertung** wird.

Der Workshop-Auftrag lautet deshalb:

```text
Finding | Bewertung | Begruendung | Empfehlung
```

## Kontext zuerst

### HealthCheckApp

- produktionskritisch
- RPO 15 Minuten
- RTO 60 Minuten
- kein akuter Incident

### LegacyReporting

- internes Reporting
- aus Quelle wieder aufbaubar
- Wiederaufbau innerhalb etwa vier Stunden akzeptabel
- kein formales Point-in-Time-RPO

Ohne diesen Kontext waere ein Teil der Bewertung falsch.

---

## Finding 1 - MAXDOP = 0

### Bewertung

**Hinweis / klaeren, nicht automatisch kritisch.**

Auf der Lab-VM stehen nur zwei vCPU zur Verfuegung. `MAXDOP = 0` ist eine Abweichung von der Common Baseline, aber noch kein Beweis fuer ein aktuelles Problem.

### Empfehlung

Workload und Parallelismus-Verhalten pruefen. Nicht allein wegen des Werts eine Performance-Ursache behaupten.

---

## Finding 2 - Memory, Cost Threshold und Backup Compression

Diese Werte sind bewusst sinnvoll gesetzt:

```text
max server memory              6144 MB
cost threshold for parallelism 50
backup compression default     ON
```

### Bewertung

**Kein Finding, das eine Aenderung verlangt.**

Ein Health Check muss auch erkennen koennen, wenn etwas bereits plausibel konfiguriert ist.

---

## Finding 3 - TempDB Growth ist nicht einheitlich

```text
tempdev   256 MB Growth
tempdev2   64 MB Growth
templog   256 MB Growth
```

### Bewertung

**Risiko / mittlere Prioritaet.**

Die beiden TempDB-Datendateien starten gleich gross, wachsen aber nicht gleich. Unter Last kann dadurch eine ungleichmaessige Dateientwicklung entstehen.

### Empfehlung

Growth der Datendateien vereinheitlichen und zusaetzlich reale TempDB-Nutzung, Storage und relevante Waits betrachten.

Nicht aus der Dateianzahl allein auf Gesundheit schliessen.

---

## Finding 4 - HealthCheckApp: zusaetzliche Datendatei auf C:

`HealthCheckApp_Archive` liegt bewusst im Verzeichnis der Systemdatenbanken.

### Bewertung

**Risiko.**

Das ist vor allem ein Betriebs- und Kapazitaetsfinding. Ob daraus aktuell ein Performanceproblem entsteht, ist damit noch nicht bewiesen.

### Empfehlung

Zweck und Nutzung der Datei pruefen und sie in ein bewusst geplantes Storage-Layout ueberfuehren.

---

## Finding 5 - HealthCheckApp: FULL Recovery, aber keine Log Backups

Das Lab erzeugt Full Backups, aber **keine Transaction Log Backups**.

### Bewertung

**Kritisch.**

Nicht weil FULL Recovery grundsaetzlich problematisch waere, sondern weil der bekannte Business-Kontext ein **RPO von 15 Minuten** fordert.

Ein taegliches Full Backup kann dieses Ziel nicht erfuellen.

### Empfehlung

Log-Backup-Strategie passend zum RPO definieren, Aufbewahrung und Monitoring einbeziehen und einen echten Restore-Test durchfuehren.

---

## Finding 6 - Gruener Full-Backup-Job

Der Job

```text
SQLDays - Slot3 - Daily Full Backup
```

laeuft erfolgreich.

### Bewertung

**Positives Betriebssignal, aber kein Recovery-Nachweis.**

Der Job beweist nur, dass ein Full Backup erstellt werden konnte.

Er beweist nicht:

- RPO 15 Minuten
- RTO 60 Minuten
- Restore-Faehigkeit
- Zugriff auf Backup-Medien im Ausfall
- fachliche Nutzbarkeit nach Restore

---

## Finding 7 - Keine lokale Restore-Historie

Auf der Lab-Instanz existiert keine Restore-Historie fuer `HealthCheckApp`.

### Bewertung

**Offene Frage / Risikoindikator.**

Wichtig: Das ist **kein Beweis**, dass niemals ein Restore getestet wurde. Der Test koennte auf einer anderen Instanz stattgefunden haben.

### Empfehlung

Restore-Test-Nachweis, Ablauf, gemessene Dauer und letzte erfolgreiche Durchfuehrung anfordern.

---

## Finding 8 - Compatibility Level 150

### Bewertung

**Kontext erforderlich.**

Ein niedrigeres Compatibility Level auf einer neueren Engine ist nicht automatisch falsch. Es kann bewusst fuer Migration, Regression-Vermeidung oder Herstellerfreigaben gesetzt worden sein.

### Empfehlung

Grund dokumentieren und pruefen, ob ein Upgrade geplant oder technisch sinnvoll ist.

Nicht als kritischen Fehler melden, nur weil die Engine neuer ist.

---

## Finding 9 - Query Store OFF

### Bewertung

**Hinweis / Empfehlung, nicht automatisch Fehler.**

Query Store ist fuer historische Performanceanalyse sehr wertvoll. Das Fehlen ist aber nicht automatisch ein aktuelles Betriebsproblem.

### Empfehlung

Bei einer produktionskritischen Anwendung die Aktivierung pruefen und bewusst konfigurieren.

---

## Finding 10 - PAGE_VERIFY CHECKSUM und AUTO_SHRINK OFF

Bei `HealthCheckApp`:

```text
PAGE_VERIFY = CHECKSUM
AUTO_SHRINK = OFF
```

### Bewertung

**Plausibler Zustand. Keine Aenderung erforderlich.**

Das Lab enthaelt diese bewusst korrekten Einstellungen, damit nicht jede abgefragte Option als Finding endet.

---

## Finding 11 - LegacyReporting: AUTO_SHRINK ON

### Bewertung

**Risiko / korrigieren.**

Die geringe Kritikalitaet der Datenbank macht `AUTO_SHRINK` nicht zu einer guten Wartungsstrategie.

### Empfehlung

AUTO_SHRINK deaktivieren. Platzbedarf und Datenlebenszyklus getrennt betrachten.

---

## Finding 12 - LegacyReporting: PAGE_VERIFY TORN_PAGE_DETECTION

### Bewertung

**Risiko.**

Fuer moderne SQL-Server-Datenbanken ist `CHECKSUM` der sinnvollere Schutz fuer Page-I/O-Fehler.

### Empfehlung

Auf `PAGE_VERIFY CHECKSUM` umstellen und Integritaetsstrategie pruefen.

---

## Finding 13 - LegacyReporting ohne Backup

### Bewertung

**Nicht automatisch kritisch. Kontext entscheidet.**

Die Datenbank ist laut Auftrag aus dem Quellsystem reproduzierbar und darf innerhalb von etwa vier Stunden neu aufgebaut werden.

Das kann eine bewusste Entscheidung sein.

### Empfehlung

Den Rebuild-Prozess, Verantwortlichkeiten und die gemessene Wiederaufbauzeit dokumentieren.

Wenn diese Annahmen nicht belastbar sind, wird daraus ein Recovery-Risiko.

---

## Finding 14 - Prozent-Autogrowth bei LegacyReporting

### Bewertung

**Technische Altlast / niedrige bis mittlere Prioritaet.**

Prozentuales Wachstum wird bei zunehmender Dateigroesse immer groesser und erschwert planbare Kapazitaet.

### Empfehlung

Auf feste, zur erwarteten Wachstumsgeschwindigkeit passende MB-/GB-Werte umstellen.

---

## Finding 15 - TRUSTWORTHY = ON bei LegacyReporting

### Bewertung

**Security-/Konfigurationsrisiko.**

`TRUSTWORTHY = ON` sollte nicht einfach als historischer Default oder Workaround bestehen bleiben.

### Empfehlung

Klaeren, warum die Option aktiviert wurde, welche Module oder Berechtigungsmodelle davon abhaengen und ob sie deaktiviert werden kann.

---

## Finding 16 - CHECKDB-Job existiert, ist aber deaktiviert

```text
SQLDays - Slot3 - Weekly CHECKDB
```

### Bewertung

**Risiko.**

Ein vorhandener Job ist keine ausgefuehrte Integritaetspruefung.

### Empfehlung

Klaeren, warum er deaktiviert wurde, Laufzeit und Wartungsfenster bestimmen und eine ueberwachte CHECKDB-Strategie etablieren.

---

## Finding 17 - Nightly Maintenance enthaelt SHRINKDATABASE

Der Job fuehrt neben Statistikpflege auch aus:

```sql
DBCC SHRINKDATABASE (N'HealthCheckApp', 10);
```

### Bewertung

**Risiko / fragwuerdige Wartungsstrategie.**

Regelmaessiges Shrinking und anschliessendes erneutes Wachstum erzeugen unnoetige Arbeit und sind kein Kapazitaetskonzept.

### Empfehlung

Shrink aus der regulaeren Wartung entfernen. Falls dauerhaft Platz zurueckgegeben werden muss, als gezielte Einzelmassnahme planen.

---

## Finding 18 - Operator zeigt auf example.invalid

### Bewertung

**Betriebsrisiko.**

Die technische Benachrichtigung ist konfiguriert, erreicht aber keinen realen Empfaenger.

### Empfehlung

Echten Empfaenger, Database Mail, Eskalation und Test der Alarmierung pruefen.

---

## Wait Statistics

`sys.dm_os_wait_stats` kann und soll im Lab betrachtet werden.

Aber die Werte wurden bewusst nicht manipuliert.

### Bewertung

Waits aus einer Test-VM sind eine Momentaufnahme beziehungsweise kumulierte Historie seit dem letzten Reset/Start.

Ein hoher Wait Type allein ist keine Root Cause.

Das entspricht dem Workshop-Grundsatz:

> **Waits zeigen Symptome, keine fertigen Ursachen.**

---

# Priorisierung

Eine moegliche Einordnung fuer dieses Lab:

## Kritisch / zeitnah handeln

- RPO 15 Minuten, aber keine Log Backups fuer `HealthCheckApp`

## Risiko / planen und korrigieren

- HealthCheckApp-Datei auf Systemlaufwerk
- uneinheitliches TempDB Growth
- CHECKDB-Job deaktiviert
- regelmaessiges SHRINKDATABASE
- unbrauchbare Operator-Adresse
- LegacyReporting AUTO_SHRINK
- LegacyReporting PAGE_VERIFY
- LegacyReporting TRUSTWORTHY ON

## Klaeren / Kontext benoetigt

- MAXDOP 0
- Compatibility Level 150
- Query Store OFF
- fehlende lokale Restore-Historie
- fehlendes Backup fuer die reproduzierbare Reporting-Datenbank

## Kein Handlungsbedarf aus diesem Finding allein

- max server memory 6144 MB auf der definierten Lab-VM
- cost threshold 50
- Backup Compression ON
- HealthCheckApp PAGE_VERIFY CHECKSUM
- HealthCheckApp AUTO_SHRINK OFF

# Kernaussage

Ein Health Check ist kein Wettbewerb um die laengste Finding-Liste.

Eine belastbare Bewertung trennt:

```text
Beobachtung
    ↓
Kontext
    ↓
Risiko
    ↓
Prioritaet
    ↓
konkrete naechste Aktion
```

**Nicht alles Rote ist dringend. Und nicht alles Unauffaellige ist gesund.**
