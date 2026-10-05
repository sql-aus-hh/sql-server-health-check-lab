# Solution 04 - Troubleshooting / Blocking, Execution Plans and Missing Index

Scenario 04 besteht bewusst aus zwei Troubleshooting-Situationen.

Beide folgen derselben Methodik:

~~~text
Symptom
  ↓
Beobachtung
  ↓
Hypothese
  ↓
Beleg
  ↓
Aenderung
  ↓
Verifikation
~~~

Der Unterschied liegt in der Ursache.

# Track A - Blocking / Locking

## Symptom

Eine Operation gegen dbo.Inventory scheint zu haengen.

Die erste falsche Reaktion waere:

> Die wartende Query ist langsam. Wir muessen sie tunen.

Zuerst muss geklaert werden, **warum sie wartet**.

## Reproduktion

Session A haelt mit einer offenen Transaktion und TABLOCKX,HOLDLOCK einen exklusiven Lock auf dbo.Inventory.

Session B fordert UPDLOCK,HOLDLOCK an und wartet.

Je nach konkretem Lock-Zustand erscheint ein LCK_M_* Wait, im getesteten Workshop-Fall beispielsweise LCK_M_IX.

## Beleg

Nicht nur nach "blocked = yes" suchen.

Mindestens erfassen:

- session_id
- blocking_session_id
- wait_type
- wait_time
- wait_resource
- offene Transaktionen
- letzte Anweisung des Blockers
- betroffene Datenbank und Objekte

Dafuer dient 03-Blocking-Observer.sql.

Besonders wichtig: Der Head Blocker kann **sleeping** sein und deshalb in sys.dm_exec_requests gar nicht als aktive Query erscheinen. Darum reicht ein Blick auf aktive Requests allein nicht.

## Root Cause

Nicht Session B ist die Ursache.

Die Ursache ist die **offen gelassene Transaktion in Session A**, die einen exklusiven Lock haelt.

Das ist der zentrale Denkpunkt:

> Blocking ist ein Symptom der Konkurrenz um dieselbe Ressource. Die wartende Session ist nicht automatisch der Verursacher.

## Aenderung und Verifikation

Im Lab wird die offene Transaktion kontrolliert mit ROLLBACK beendet.

Danach pruefen:

- Session B laeuft weiter
- blocking_session_id verschwindet
- kein LCK_M_* Wait mehr fuer die Demo-Session
- offene Transaktion ist beendet

# Track B - Execution Plan / Missing Index / Query Store

## Symptom

Die Customer-Order-Suche ist deutlich langsamer als zuvor.

Die Query filtert dbo.SalesOrder nach CustomerId und OrderDate und sortiert nach OrderDate. Die Tabelle enthaelt 1.200.000 Zeilen.

## Was das Setup vorbereitet

Zunaechst existiert folgender Supporting Index:

~~~sql
CREATE INDEX IX_SalesOrder_Customer_OrderDate
ON dbo.SalesOrder
(
    CustomerId,
    OrderDate
)
INCLUDE
(
    Status,
    TotalAmount
);
~~~

Mit diesem Index wird dieselbe Query mehrfach ausgefuehrt und Query Store zeichnet den guten Plan auf.

Danach wird der Index entfernt und dieselbe Query erneut ausgefuehrt. Query Store besitzt dadurch historische Evidenz fuer **dieselbe Abfrage vor und nach der Aenderung**.

# Execution Plan lesen

05-ExecutionPlan-Bad.sql mit aktiviertem Actual Execution Plan ausfuehren.

Nicht direkt auf die gruene Missing-Index-Zeile springen.

## 1. Access Method

Die zentrale Frage lautet:

> Wie kommt SQL Server an die benoetigten Zeilen?

Der relevante Unterschied ist im Lab:

~~~text
mit Supporting Index     → gezielter Index Seek
ohne Supporting Index    → breiter Scan
~~~

## 2. Predicate

Pruefen, wo CustomerId und OrderDate angewendet werden.

Wenn eine grosse Datenmenge erst gelesen und danach weggefiltert wird, ist das ein entscheidender Hinweis.

## 3. Estimated Rows vs. Actual Rows

Diese Werte beantworten eine andere Frage als "Seek oder Scan".

Grosse Abweichungen koennen auf Cardinality- oder Statistik-Probleme hinweisen. In diesem Lab ist der fehlende Zugriffspfad die vorbereitete Hauptursache, trotzdem sollte der Vergleich immer Teil der Plananalyse sein.

## 4. Logical Reads

SET STATISTICS IO ON liefert den belastbareren Vergleich als nur eine Stoppuhr.

Die exakten Zahlen haengen von Engine, Cache und VM ab. Erwartet wird jedoch ein deutlicher Unterschied:

~~~text
Supporting Index vorhanden  → sehr wenige Reads
Supporting Index entfernt   → viele tausend Reads / grosser Scan
~~~

## 5. Kostenprozent im Plan

Die Prozentwerte im grafischen Plan sind **Optimizer-Schaetzungen innerhalb genau dieses Plans**.

Sie sind weder reale Zeitanteile noch ein Vergleich mit einem anderen Plan.

Darum nicht behaupten, ein Operator habe beispielsweise 90 Prozent der realen Laufzeit verursacht, nur weil der grafische Plan dort 90 Prozent Kosten zeigt.

# Missing Index Recommendation

Der schlechte Plan sollte einen Missing-Index-Hinweis fuer dbo.SalesOrder zeigen.

Sinngemaess wird ein Zugriffspfad ueber CustomerId und OrderDate mit INCLUDE-Spalten Status und TotalAmount vorgeschlagen.

Eine Missing-Index-Empfehlung ist aber **eine Hypothese des Optimizers, kein Change Request**.

Vor dem Erstellen pruefen:

- Welche Indizes existieren bereits?
- Gibt es einen aehnlichen Index, den man erweitern kann?
- Ist die Query wichtig genug?
- Wie oft laeuft sie?
- Wie hoch sind die DML-Kosten des neuen Index?
- Sind alle vorgeschlagenen INCLUDE-Spalten wirklich sinnvoll?
- Kann ein vorhandener Index konsolidiert werden?

Das Lab ist absichtlich so gebaut, dass die Empfehlung hier fachlich sinnvoll ist. In einer echten Umgebung muss das erst bewiesen werden.

# Query Store: historische Evidenz

06-QueryStore-Compare.sql zeigt die Plaene derselben parameterisierten Query.

Der alte Plan enthaelt den Supporting Index. Der neue Plan wurde nach dem Entfernen des Index kompiliert.

Damit kann Query Store die entscheidende historische Frage beantworten:

> Was war vorher anders?

Das kann der aktuelle Plan Cache allein nicht verlaesslich beantworten.

# Fix

Fuer dieses reproduzierbare Lab ist der passende Index bekannt:

~~~sql
CREATE INDEX IX_SalesOrder_Customer_OrderDate
ON dbo.SalesOrder
(
    CustomerId,
    OrderDate
)
INCLUDE
(
    Status,
    TotalAmount
);
~~~

Anschliessend die Lookup-Query erneut mit Actual Execution Plan und STATISTICS IO/TIME ausfuehren.

# Verifikation

Nach dem Fix nicht bei "Index wurde erstellt" aufhoeren.

Vergleichen:

## Vorher

- Scan
- hohe logical reads
- laengere Laufzeit
- Missing-Index-Hinweis
- Bad Plan im Query Store

## Nachher

- gezielter Zugriff ueber den Supporting Index
- deutlich weniger logical reads
- bessere Laufzeit
- neuer Plan nach der DDL-Aenderung

Die Missing-Index-DMVs sind dabei **kein geeigneter alleiniger Nachweis**, weil ihre Eintraege volatile beziehungsweise historische Optimizer-Empfehlungen darstellen.

Der belastbare Nachweis ist der Vorher-/Nachher-Vergleich der realen Query.

# Root Cause vs. Nebenbefund

Das ist die eigentliche Verbindung beider Tracks.

Wenn gerade die Inventory-Operation haengt, ist der fehlende SalesOrder-Index nicht die Ursache dieses Symptoms.

Und wenn die Customer-Order-Suche nach dem Entfernen des Index viele Daten scannt, darf ein anderes auffaelliges Finding nicht automatisch zur Root Cause erklaert werden.

Troubleshooting fragt immer:

> **Welcher Befund erklaert genau das konkrete Symptom, das wir gerade untersuchen?**

# Kernaussage

~~~text
Wait Type      ≠ Root Cause
Blocking       ≠ automatisch schlechte wartende Query
hohe CPU       ≠ Root Cause
Missing Index  ≠ automatisch CREATE INDEX
Execution Plan ≠ Screenshot zum Ablesen
~~~

Gute Fehlersuche verbindet Beobachtungen zu einer beweisbaren Ursache und prueft danach, ob die Aenderung wirklich wirkt.

**Measure. Change. Verify.**
