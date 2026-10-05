# Solution 02 - Take Ownership / Recovery Readiness

Scenario 02 ist kein reines Restore-Lab.

Die eigentliche Betriebsfrage lautet:

> **Ist diese Umgebung so verstanden und abgesichert, dass ich morgen Verantwortung dafuer uebernehmen kann?**

Ein erfolgreicher SQL-Agent-Job ist dabei nur ein Finding. Er ist noch kein Beweis fuer eine belastbare Recovery-Strategie.

## 1. Umgebung erfassen

Zuerst sollten mindestens die beteiligten Datenbanken und ihre Recovery Models erfasst werden:

```sql
SELECT
    name,
    state_desc,
    recovery_model_desc
FROM sys.databases
WHERE name IN
(
    N'WorkshopOps',
    N'WorkshopOps_Audit'
);
```

Dabei faellt bereits auf:

- `WorkshopOps` verwendet `FULL`.
- `WorkshopOps_Audit` gehoert ebenfalls zur vorbereiteten Umgebung.
- Die beiden Datenbanken muessen deshalb gemeinsam aus Betriebssicht bewertet werden.

## 2. Backup-Historie pruefen

Nicht nur den SQL-Agent-Job ansehen, sondern die tatsaechlich erzeugten Backups:

```sql
SELECT
    bs.database_name,
    bs.type,
    CASE bs.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFF'
        WHEN 'L' THEN 'LOG'
        ELSE bs.type
    END AS BackupType,
    bs.is_copy_only,
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.first_lsn,
    bs.last_lsn,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
  ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name IN
(
    N'WorkshopOps',
    N'WorkshopOps_Audit'
)
ORDER BY
    bs.database_name,
    bs.backup_finish_date;
```

### Finding 1: WorkshopOps_Audit ist nicht geschuetzt

Der vorbereitete SQL-Agent-Job ist erfolgreich, erfasst aber nur `WorkshopOps`.

`WorkshopOps_Audit` besitzt keine Backup-Historie.

Das ist genau der Unterschied zwischen:

```text
Job ist gruen
```

und

```text
die Anwendung ist recoverable
```

## 3. COPY_ONLY Backup richtig einordnen

Der Agent Job erzeugt:

```text
G:\SQLBackup\Slot2\WorkshopOps_JOB_COPYONLY.bak
```

Dieses Backup wurde **nach** dem Zustand `AFTER_TARGET_DO_NOT_INCLUDE` erzeugt.

Es ist deshalb fuer die konkrete Aufgabe, den frueheren Zustand `SLOT2_TARGET` wiederherzustellen, nicht der geeignete Ausgangspunkt.

Die kontrollierte Kette lautet:

```text
WorkshopOps_FULL.bak
    ↓
WorkshopOps_LOG_01.trn
    ↓
WorkshopOps_LOG_02.trn
```

`WorkshopOps_LOG_03.trn` enthaelt bereits den Zustand, der nicht mehr Teil des Restore-Ergebnisses sein soll.

## 4. Restore auf WorkshopLab_Restore

### FULL

```sql
RESTORE DATABASE [WorkshopLab_Restore]
FROM DISK = N'G:\SQLBackup\Slot2\WorkshopOps_FULL.bak'
WITH
    MOVE N'WorkshopOps'
        TO N'E:\SQLData\WorkshopLab_Restore.mdf',
    MOVE N'WorkshopOps_log'
        TO N'F:\SQLLog\WorkshopLab_Restore_log.ldf',
    NORECOVERY,
    REPLACE,
    STATS = 10;
```

### LOG 01

```sql
RESTORE LOG [WorkshopLab_Restore]
FROM DISK = N'G:\SQLBackup\Slot2\WorkshopOps_LOG_01.trn'
WITH
    NORECOVERY,
    STATS = 10;
```

### LOG 02 - Zielzustand

```sql
RESTORE LOG [WorkshopLab_Restore]
FROM DISK = N'G:\SQLBackup\Slot2\WorkshopOps_LOG_02.trn'
WITH
    RECOVERY,
    STATS = 10;
```

`LOG_03` wird bewusst **nicht** angewendet.

Ein `STOPAT` waere fuer eine echte Point-in-Time-Recovery eine wichtige Technik. Fuer dieses Lab ist der Zielzustand jedoch absichtlich entlang der Backup-Grenze von `LOG_02` vorbereitet, damit die Restore-Kette reproduzierbar und ohne Zeitabhaengigkeit nachvollziehbar bleibt.

## 5. Fachlichen Datenstand pruefen

### Marker

```sql
SELECT
    MarkerId,
    MarkerName,
    MarkerUtc
FROM WorkshopLab_Restore.dbo.LabMarker
ORDER BY MarkerId;
```

Erwartet:

```text
FULL_BASELINE
LOG_01_APPLIED
SLOT2_TARGET
```

Nicht enthalten:

```text
AFTER_TARGET_DO_NOT_INCLUDE
```

### Orders

```sql
SELECT
    OrderId,
    OrderNo,
    Amount,
    CreatedUtc
FROM WorkshopLab_Restore.dbo.Orders
ORDER BY OrderId;
```

`OPS-1201` muss vorhanden sein.

`OPS-1301` darf nicht vorhanden sein.

## 6. Technische Konsistenz pruefen

Ein erfolgreich abgeschlossener Restore ist noch nicht das Ende der Validierung:

```sql
DBCC CHECKDB (N'WorkshopLab_Restore')
WITH NO_INFOMSGS;
```

## 7. Findings bewerten

### Change now

- `WorkshopOps_Audit` ist nicht in der Backup-Strategie enthalten.
- Die Benachrichtigung verwendet lediglich die Lab-Adresse `dba@example.invalid`.

### Clarify first

- Welches RPO gilt fuer `WorkshopOps`?
- Welches RPO gilt fuer `WorkshopOps_Audit`?
- Muessen beide Datenbanken konsistent auf denselben fachlichen Zeitpunkt restauriert werden?
- Wie lange darf ein Restore dauern?
- Wo werden Backups ausserhalb dieses Servers aufbewahrt?
- Wann wurde der letzte reale Restore-Test durchgefuehrt?

### Document only / verstehen

- Der zusaetzliche `COPY_ONLY` Full Backup ist nicht automatisch problematisch.
- Entscheidend ist, welchen Zweck er hat und wie er sich in die Recovery-Dokumentation einordnet.

## Kernaussage

**Gruene Jobs sind Betriebsindikatoren, keine Recovery-Beweise.**

Recovery ist erst dann belastbar, wenn klar ist:

- welche Daten gesichert werden,
- welche Daten nicht gesichert werden,
- welche Kette fuer einen Zielzustand benoetigt wird,
- wie lange die Wiederherstellung dauert,
- und wie der wiederhergestellte Zustand technisch und fachlich validiert wird.
