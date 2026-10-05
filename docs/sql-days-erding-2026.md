# SQLDays 2026 Erding

Dieses Repository entstand aus dem Workshop **SQL Server Health Check** bei den SQLDays 2026 in Erding.

Während des Workshops konnten die vorbereiteten Hands-on-Umgebungen nicht wie ursprünglich geplant genutzt werden. Die eigentlichen Inhalte ließen sich dennoch gemeinsam durchgehen. Im Anschluss kam aus dem Teilnehmerkreis die Frage auf, ob die verwendeten Szenarien so veröffentlicht werden können, dass man sie auf einer eigenen SQL Server Test-VM selbst nachbauen kann.

Genau das ist das Ziel dieses Repositories.

## Ziel

Die Umgebung soll aus zwei Teilen bestehen:

1. einem gemeinsamen Ausgangszustand (**Common Setup**)
2. vier reproduzierbaren Workshop-Szenarien

Jedes Szenario soll später mindestens enthalten:

- Beschreibung des gewünschten Ausgangszustands
- Setup-Skript
- Validierung
- Hinweise für die Analyse
- Cleanup
- getrennte Lösung bzw. Auflösung

## Vorgehen

Die Szenarien werden nicht als fertige "Fehler + Lösung"-Demos gedacht, sondern als kleine Troubleshooting-Labs:

```text
Common Setup
    ↓
Scenario Setup
    ↓
Validate
    ↓
Analyse
    ↓
Ursache verstehen
    ↓
Lösung
    ↓
Cleanup
```

## Hinweis

Die Skripte sind ausschließlich für Test- und Lernumgebungen gedacht. Einzelne Szenarien können bewusst ungünstige oder fehlerhafte SQL Server Zustände erzeugen.
