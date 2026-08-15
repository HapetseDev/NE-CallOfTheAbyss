# Entwicklung eines Inventarsystems für „NE – Call of the Abyss“

Du arbeitest als erfahrener Godot-4-Gamedesigner und GDScript-Entwickler an meinem bestehenden Projekt:

**GitHub Repository:**  
https://github.com/HapetseDev/NE-CallOfTheAbyss

Als konzeptionelle Grundlage dient dieses Tutorial:

**YouTube:**  
https://www.youtube.com/watch?v=V79YabQZC1s&list=WL&index=13

## Wichtig: Nicht blind nachbauen

Analysiere zunächst das bestehende Repository und verstehe dessen Architektur, bevor du Änderungen vorschlägst oder Code erzeugst.

Das Inventarsystem aus dem Tutorial soll **nicht 1:1 kopiert** werden.

Übertrage stattdessen die zugrunde liegenden Konzepte auf die bestehende Architektur von „NE – Call of the Abyss“.

Vermeide insbesondere:

- doppelte Systeme
- neue globale Manager, wenn bereits vorhandene Autoloads dafür geeignet sind
- unnötige Singletons
- harte Abhängigkeiten zwischen Inventar und UI
- Logik direkt in UI-Szenen
- Änderungen an bestehenden Systemen, wenn diese nicht notwendig sind
- eine Architektur, die später Ausrüstung, Verbrauchsgegenstände, Questgegenstände, Loot, Shops und Crafting nicht erweitern kann

---

# 1. Zuerst das bestehende Projekt analysieren

Untersuche insbesondere:

- `project.godot`
- vorhandene Autoloads
- `GameState`
- `GlobalLevelManager`
- `ShopManager`
- `BattleManager`
- Character-System
- Player-System
- State Machine
- UI-Struktur
- vorhandene Resources
- vorhandene Datenmodelle
- vorhandene Interaktionssysteme
- vorhandene Shop-/Handelslogik
- vorhandene Dialogsysteme

Achte besonders darauf, welche Systeme bereits für globale Spieldaten zuständig sind.

Im Projekt existiert bereits die Input Action:

`Inventar`

Diese ist aktuell auf die Taste **I** gelegt.

Das Inventar soll deshalb über diese bestehende Input Action geöffnet und geschlossen werden. Erstelle keine zweite Input Action dafür.

---

# 2. Ziel des Inventarsystems

Implementiere ein modular aufgebautes Inventarsystem für ein Fantasy-RPG.

Das System soll zunächst folgende grundlegenden Funktionen unterstützen:

1. Items definieren
2. Items im Inventar speichern
3. Items aufnehmen
4. Items entfernen
5. Item-Anzahl verwalten
6. stapelbare Items unterstützen
7. nicht stapelbare Items unterstützen
8. Inventarplätze verwalten
9. Inventar anzeigen
10. Inventar öffnen und schließen
11. Items auswählen
12. Items verwenden
13. Items später per Drag & Drop verschieben können
14. Items später aus dem Inventar entfernen/droppen können

Die Architektur soll bereits so vorbereitet sein, dass später problemlos ergänzt werden können:

- Ausrüstung
- Waffen
- Rüstung
- Accessoires
- Verbrauchsgegenstände
- Questgegenstände
- Schlüsselgegenstände
- Munition
- Nahrung
- Tränke
- Materialien
- Crafting
- Loot
- Händler
- Charakter-spezifische Inventare
- Container/Truhen
- Gewicht
- Sortierung
- Filter
- Item-Stacks
- Save/Load

Diese Funktionen müssen jedoch nicht alle sofort implementiert werden.

---

# 3. Architektur

Verwende eine klare Trennung zwischen:

## Item-Daten

Definiert, **was ein Item grundsätzlich ist**.

Beispielsweise:

- ID
- Anzeigename
- Beschreibung
- Icon
- Item-Typ
- Stapelbarkeit
- maximale Stack-Größe
- Wert
- Gewicht
- eventuell Seltenheit
- eventuell Nutzbarkeit

Für statische Itemdefinitionen darf und soll eine Godot-`Resource` beziehungsweise ein entsprechendes `Resource`-basiertes Datenmodell verwendet werden.

Beispiel:

```gdscript
class_name ItemData
extends Resource
```

Die konkreten Eigenschaften sollen aber an die vorhandene Architektur des Projekts angepasst werden.

---

## Inventar-Daten

Das Inventar soll nicht direkt aus UI-Nodes bestehen.

Es soll eine eigene Datenstruktur geben, die beschreibt:

> Welche Items besitzt der Spieler und in welcher Menge?

Beispielsweise:

```text
Inventory
 ├── Slot 0
 │    ├── Item
 │    └── Amount
 ├── Slot 1
 │    ├── Item
 │    └── Amount
 └── ...
```

Die genaue Implementierung soll anhand des bestehenden Projekts entschieden werden.

---

## Inventar-UI

Die UI soll lediglich das Inventar darstellen und Benutzeraktionen an das Inventarsystem weitergeben.

Nicht:

```text
UI verändert direkt Inventardaten
```

Sondern:

```text
Player / Game Systems
        ↓
   Inventory Data
        ↓
    Inventory UI
```

Änderungen am Inventar sollen anschließend die UI aktualisieren.

---

# 4. Integration in das bestehende Projekt

Nutze die vorhandene Projektstruktur.

Bevor neue Ordner angelegt werden, prüfe, ob ein vorhandener Ordner für die jeweilige Funktion geeignet ist.

Eine mögliche Struktur wäre beispielsweise:

```text
Systems/
└── Inventory/
    ├── inventory.gd
    ├── inventory_slot.gd
    ├── item_data.gd
    └── ...

Resources/
└── Inventory/
    ├── Items/
    └── ...

UI/
└── Inventory/
    ├── Inventory.tscn
    ├── Inventory.gd
    ├── InventorySlot.tscn
    └── InventorySlot.gd
```

Diese Struktur ist nur ein Vorschlag.

Passe sie an die tatsächlich vorhandene Struktur des Repositorys an.

---

# 5. Globales Inventar

Prüfe zuerst, ob das Inventar Teil von `GameState` sein sollte.

Da im Projekt bereits ein `GameState`-Autoload existiert, soll **nicht automatisch ein zusätzlicher `InventoryManager`-Autoload erstellt werden**.

Beurteile anhand der bestehenden Architektur:

- Was gehört in `GameState`?
- Was gehört in ein eigenes Inventory-System?
- Welche Daten müssen global verfügbar sein?
- Welche Daten gehören zum Spieler?

Bevor du einen neuen Autoload einführst, begründe ausdrücklich, warum dieser notwendig ist.

---

# 6. Item-System

Erstelle ein erweiterbares Item-Datenmodell.

Ein Item sollte mindestens folgende Informationen besitzen können:

```text
ID
Name
Beschreibung
Icon
Item-Typ
stapelbar
maximale Stack-Größe
Wert
Gewicht
```

Der Item-Typ soll nicht als frei eingegebener String gespeichert werden.

Verwende nach Möglichkeit ein Enum oder eine andere typsichere Struktur.

Beispielsweise:

```text
CONSUMABLE
WEAPON
ARMOR
ACCESSORY
QUEST
MATERIAL
KEY_ITEM
MISC
```

Passe die Kategorien an das Spiel „NE – Call of the Abyss“ an.

---

# 7. Inventar-Slots

Implementiere ein Slot-System.

Ein Slot enthält beispielsweise:

```text
ItemData
Amount
```

Ein leerer Slot enthält kein Item.

Das Inventar soll erkennen können:

- ob ein Slot leer ist
- ob ein Item hineingelegt werden kann
- ob ein vorhandener Stack erweitert werden kann
- ob ein neuer Slot benötigt wird
- ob das Inventar voll ist

---

# 8. Stacking

Stapelbare Items sollen automatisch zusammengefasst werden.

Beispiel:

Spieler besitzt:

```text
Potion × 5
```

Der Spieler nimmt:

```text
Potion × 3
```

Ergebnis:

```text
Potion × 8
```

Wenn die maximale Stackgröße beispielsweise 10 beträgt:

```text
Potion × 10
Potion ×  - 1
```

Das System muss also mit Überläufen umgehen können.

Die genaue Logik soll sauber im Inventarsystem und nicht in der UI implementiert werden.

---

# 9. Hinzufügen und Entfernen

Das Inventarsystem soll eine klare API besitzen.

Beispielsweise sinngemäß:

```gdscript
add_item(item, amount)
remove_item(item, amount)
has_item(item, amount)
get_item_count(item)
```

Die tatsächlichen Methodennamen darfst du sinnvoll wählen.

Wichtig ist eine klare Trennung zwischen:

```text
Inventory Logic
```

und

```text
UI
```

---

# 10. UI

Erstelle eine einfache, funktionale Inventaroberfläche.

Die endgültige Gestaltung soll zum bestehenden Stil des Spiels passen.

Die UI soll zunächst enthalten:

- Inventarfenster
- Inventartitel
- Grid mit Slots
- Item-Icon
- Anzahl bei gestapelten Items
- Hervorhebung des ausgewählten Slots
- optional Tooltip
- Schließen des Inventars

Das Inventar soll über die bestehende Action:

```text
Inventar
```

geöffnet und geschlossen werden.

---

# 11. Integration mit der Player-State-Machine

Das bestehende Projekt verwendet eine State Machine.

Prüfe, ob das Öffnen des Inventars einen eigenen State benötigt.

Eine mögliche Struktur wäre:

```text
StateMachine
├── Idle
├── Walk
├── ActionMenu
└── Inventory
```

Führe einen solchen State aber nur ein, wenn dies mit der bestehenden Architektur sinnvoll ist.

Das Inventar darf insbesondere nicht dazu führen, dass der Spieler sich weiter bewegt, während ein modales Inventar geöffnet ist.

Während das Inventar geöffnet ist:

- keine normale Spielerbewegung
- keine Weltinteraktion
- keine unbeabsichtigten Aktionen
- UI-Eingaben müssen funktionieren

Beim Schließen soll der vorherige Zustand korrekt wiederhergestellt werden.

---

# 12. Items aufnehmen

Das System soll später mit Weltobjekten verbunden werden können.

Beispiel:

```text
World Item
    ↓
Player Interaction
    ↓
Inventory.add_item()
    ↓
Inventory aktualisiert sich
    ↓
World Item wird entfernt
```

Implementiere zunächst eine einfache Testmöglichkeit.

Beispielsweise kann ein Test-Item beim Start in das Inventar gelegt werden.

Verändere dafür nicht unnötig die bestehende Weltlogik.

---

# 13. Shops

Im Repository existiert bereits ein `ShopManager`.

Das Inventarsystem muss deshalb so konzipiert werden, dass Händler später Items hinzufügen und entfernen können.

Beispielsweise:

```text
Shop
 ↓
Inventory API
```

Der Shop soll nicht direkt auf interne Slot-Daten zugreifen.

Später soll dadurch Folgendes möglich sein:

```text
Kaufen:
Shop → Item → Player Inventory

Verkaufen:
Player Inventory → Item → Shop
```

Das muss noch nicht vollständig implementiert werden.

Die Schnittstelle soll jedoch berücksichtigt werden.

---

# 14. Battle-System

Im Projekt existiert bereits ein rundenbasiertes Battle-System.

Das Inventar soll später auch aus dem Kampfsystem heraus verwendet werden können.

Beispielsweise:

```text
Battle
 └── Item
      ├── Heiltrank
      ├── Gegenstand
      └── ...
```

Das Inventarsystem darf deshalb nicht ausschließlich auf Exploration/UI ausgelegt werden.

Es sollte eine saubere API für zukünftige Nutzung aus anderen Systemen bereitstellen.

---

# 15. Save/Load

Analysiere das bestehende Save-/GameState-System.

Implementiere nicht ungefragt ein zweites Save-System.

Das Inventar muss später speicherbar sein.

Dabei sollten nicht komplette Resource-Objekte blind serialisiert werden.

Nutze stattdessen stabile Item-IDs.

Beispielsweise:

```text
Item ID: potion_health
Amount: 4
Slot: 7
```

Beim Laden wird anhand der ID die entsprechende `ItemData`-Resource gefunden.

---

# 16. Godot-Version

Das Projekt verwendet aktuell:

```text
Godot 4.7
Forward+
```

Schreibe ausschließlich kompatiblen Godot-4.7-GDScript-Code.

Verwende keine Godot-3-Syntax.

Vermeide veraltete APIs.

---

# 17. Bestehenden Code respektieren

Das ist besonders wichtig.

Bevor du eine Datei veränderst:

1. Lies ihren aktuellen Inhalt.
2. Verstehe ihre Aufgabe.
3. Prüfe ihre Abhängigkeiten.
4. Prüfe, ob andere Systeme sie verwenden.
5. Verändere nur das Notwendige.

Keine unnötigen Refactorings.

Keine großflächige Umstrukturierung des Projekts.

Keine Umbenennung bestehender Systeme ohne zwingenden Grund.

---

# 18. Vorgehensweise

Arbeite in kleinen, nachvollziehbaren Schritten.

## Phase 1 – Analyse

Analysiere zuerst:

- Projektstruktur
- GameState
- Player
- State Machine
- UI
- ShopManager
- vorhandene Resources
- Input-System

Gib anschließend eine kurze Beschreibung aus:

```text
Bestehende Architektur
↓
Geplante Inventararchitektur
↓
Welche Dateien neu entstehen
↓
Welche Dateien verändert werden
↓
Warum diese Integration sinnvoll ist
```

Noch keinen großen Codeblock erzeugen.

---

## Phase 2 – Datenmodell

Implementiere:

- ItemData
- Item-Typen
- InventorySlot
- Inventory

Teste zunächst ausschließlich die Datenlogik.

---

## Phase 3 – UI

Implementiere:

- Inventory.tscn
- Inventory.gd
- InventorySlot.tscn
- InventorySlot.gd

Verbinde anschließend die UI mit dem Inventar.

---

## Phase 4 – Player Integration

Verbinde das Inventar mit:

```text
Inventar = I
```

und verhindere während der Inventarnutzung normale Spieleraktionen.

---

## Phase 5 – Test

Erstelle einige Test-Items:

```text
Heiltrank
Mana-/Magietrank
Schlüssel
Questgegenstand
Schwert
```

Teste:

- Item hinzufügen
- Item entfernen
- Stacken
- Stack-Limit
- Inventar voll
- UI-Aktualisierung
- Öffnen/Schließen
- Auswahl
- Verwendung eines Items

---

# 19. Codequalität

Der Code soll:

- idiomatisches GDScript verwenden
- `class_name` sinnvoll einsetzen
- typed GDScript verwenden
- Signals verwenden, wo sie sinnvoll sind
- keine unnötigen globalen Variablen verwenden
- keine UI-Referenzen im Datenmodell verwenden
- keine zyklischen Abhängigkeiten erzeugen
- leicht erweiterbar sein

Vermeide insbesondere eine Architektur wie:

```text
Inventory.gd
    ↓
InventoryUI.gd
    ↓
Player.gd
    ↓
GameState.gd
    ↓
Inventory.gd
```

wenn dadurch zyklische Abhängigkeiten entstehen.

---

# 20. Ergebnis

Am Ende soll ein funktionierendes, aber bewusst einfach gehaltenes Inventarsystem entstehen.

Die wichtigste Eigenschaft ist nicht die Anzahl der Features, sondern eine **saubere Grundlage für die weitere Entwicklung von NE – Call of the Abyss**.

Das System soll später problemlos erweitert werden können um:

```text
Inventory
├── Items
├── Equipment
├── Consumables
├── Quest Items
├── Loot
├── Shops
├── Containers
├── Crafting
└── Save/Load
```

Beginne mit der Analyse des bestehenden Repositorys.

Erkläre zunächst deine geplante Architektur und die konkreten Dateien, die du anlegen oder verändern würdest.

**Implementiere noch nichts, bevor die Architektur anhand des bestehenden Projekts überprüft wurde.**