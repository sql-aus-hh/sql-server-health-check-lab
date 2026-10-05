# Solution 01 - Build / Setup Review

Dieses Szenario soll bewusst zeigen, warum ein Health Check nicht aus einer Liste vermeintlich "richtiger Werte" bestehen sollte.

Die Aufgabe ist nicht, jede Abweichung sofort zu korrigieren. Zuerst muss verstanden werden, **welche Einstellung welchen Einfluss hat und ob sie in dieser Umgebung ueberhaupt ein Problem darstellt.**

## Findings

### max server memory

Der Defaultwert laesst SQL Server praktisch den gesamten verfuegbaren Speicher nutzen.

Auf der Workshop-VM mit 8 GiB RAM sollte deshalb bewusst Speicher fuer Betriebssystem und weitere Prozesse reserviert werden.

Fuer die Lab-Baseline verwenden wir:

```sql
EXEC sys.sp_configure N'max server memory (MB)', 6144;
RECONFIGURE;
```

Das ist ein **Lab-Wert**, keine allgemeingueltige Produktionsregel.

### MAXDOP

`MAXDOP = 0` bedeutet nicht automatisch, dass ein Server fehlerhaft konfiguriert ist. Auf einer kleinen VM mit zwei vCPU ist es aber ein guter Anlass, die Parallelismus-Konfiguration bewusst zu pruefen.

Die Lab-Baseline verwendet `MAXDOP = 2`.

### Cost Threshold for Parallelism

Der historische Defaultwert `5` ist auf modernen Systemen oft zu niedrig.

Im Lab verwenden wir `50` als bewusst gesetzten Ausgangspunkt. Auch dieser Wert ist keine universelle Empfehlung, sondern muss mit dem Workload bewertet werden.

### Backup Compression

`backup compression default = 0` verhindert nicht, dass einzelne Backups komprimiert werden. Ohne explizite Option werden sie jedoch unkomprimiert erstellt.

Im Lab aktivieren wir die Default-Kompression.

### Optimize for Ad Hoc Workloads

Bei Workloads mit vielen einmalig ausgefuehrten Ad-hoc-Abfragen kann die Option den Plan Cache entlasten.

Ob sie sinnvoll ist, sollte anhand des Workloads entschieden werden. Im Lab ist sie Teil der Baseline.

### TempDB

Im Szenario liegen die TempDB-Dateien absichtlich auf dem Systemlaufwerk und verwenden sehr kleine Growth-Schritte.

Die Workshop-Baseline verwendet das separate lokale Laufwerk:

```text
D:\SQLTempDB
```

Entscheidend sind dabei nicht nur "C: ist schlecht" oder "D: ist gut", sondern Storage-Eigenschaften, Persistenz, Performance, Dateigroessen und Growth-Verhalten.

### Default Data / Log

Die Default-Pfade zeigen im Szenario auf das Systemlaufwerk.

Die Lab-Baseline trennt sie:

```text
E:\SQLData
F:\SQLLog
G:\SQLBackup
```

Das allein garantiert noch keine gute Storage-Architektur, sorgt aber fuer einen definierten und nachvollziehbaren Aufbau der Testumgebung.

### 1 MB Autogrowth

Die WorkshopLab-Dateien wachsen absichtlich in 1-MB-Schritten.

Das kann bei wachsenden Datenbanken zu vielen kleinen Growth Events und unnoetiger Verwaltungsarbeit fuehren.

Die Lab-Baseline verwendet feste 256-MB-Schritte.

### AUTO_SHRINK

`AUTO_SHRINK = ON` gehoert zu den klaren Findings dieses Szenarios.

Eine Datenbank automatisch zu verkleinern, um sie spaeter durch Autogrowth wieder wachsen zu lassen, ist keine sinnvolle regulaere Wartungsstrategie.

### FULL Recovery ohne Backup-Strategie

`FULL` ist nicht falsch.

Problematisch ist die Kombination aus FULL Recovery und fehlender dazu passender Backup-Strategie.

Wenn Point-in-Time-Recovery benoetigt wird, gehoeren regelmaessige Transaction Log Backups dazu. Fuer die einfache Lab-Baseline verwenden wir dagegen `SIMPLE`.

### PAGE_VERIFY CHECKSUM

Hier soll **nichts repariert werden**.

`PAGE_VERIFY = CHECKSUM` ist der gewuenschte Zustand.

### AUTO_CLOSE OFF

Auch diese Einstellung ist bereits sinnvoll.

Das ist ein wichtiger Teil der Uebung: Ein Health Check soll nicht automatisch jede abgefragte Einstellung als Finding deklarieren.

## Kernaussage

Ein auffaelliger Wert ist noch keine Ursache.

Eine Default-Einstellung ist nicht automatisch falsch.

Und eine Abweichung von einer Best Practice ist erst dann relevant, wenn sie im Kontext der konkreten Umgebung verstanden wurde.
