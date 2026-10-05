# Workshop Scenarios

Die vier Workshop-Szenarien bilden unterschiedliche Perspektiven auf denselben SQL-Server-Lifecycle ab.

## Scenario 01 - Build / Setup Review

[Scenario 01](01/) betrachtet eine installierte Instanz und typische Setup-/Default-Entscheidungen.

Leitfrage:

> Ist der Server nur installiert oder sinnvoll vorbereitet?

**Status:** umgesetzt.

## Scenario 02 - Take Ownership / Recovery Readiness

[Scenario 02](02/) betrachtet die Betriebsuebernahme mit Fokus auf Backup, SQL Agent und nachweisbare Recovery.

Leitfrage:

> Der Server laeuft. Koennen wir ihn morgen wirklich verantworten?

**Status:** umgesetzt.

## Scenario 03 - Health Check / Assess, Don't Assume

[Scenario 03](03/) bildet einen Health Check mit gemischten Findings ab. Die Aufgabe ist nicht, moeglichst viele Abweichungen zu finden, sondern sie im Kontext zu bewerten und zu priorisieren.

Leitfrage:

> Ist diese Umgebung gesund genug fuer den Betrieb?

**Status:** umgesetzt.

## Scenario 04 - Troubleshooting / Diagnose unter Druck

[Scenario 04](04/) kombiniert zwei reproduzierbare Troubleshooting-Tracks: Blocking/Locking sowie Execution Plan, Missing Index und Query-Store-Vergleich.

Leitfrage:

> Welcher Befund erklaert das konkrete Symptom wirklich?

**Status:** umgesetzt.

## Einheitlicher Aufbau

Jedes Scenario verwendet nach der Aufbereitung moeglichst dieselbe Struktur:

```text
README.md
Setup.sql
Validate.sql
Cleanup.sql
```

Die eigentlichen Loesungen liegen bewusst getrennt unter [../solutions](../solutions/), damit die Labs zunaechst ohne Spoiler als Uebung genutzt werden koennen.
