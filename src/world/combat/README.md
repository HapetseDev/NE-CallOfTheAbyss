# Fluchtbereiche

Beide spielbaren Levels enthalten `Fluchtbereiche/Party` und
`Fluchtbereiche/Gegner`. Im Godot-3D-Editor den jeweiligen Bereich verschieben.
Unter `CollisionShape3D → Shape → Size` lässt sich das Zielgebiet vergrößern.
Die Box muss begehbaren Boden einschließen und ausreichend Platz für die Figuren
bieten. Nicht auf Levelausgänge oder mitten in andere Begegnungen setzen.
Die Bereiche sind im Spiel unsichtbar und lösen beim Betreten nichts aus.

Nach einem erfolgreichen Fluchtwurf sucht `CombatSession.mark_fled()` einen
kollisionsfreien Weg zum passenden Bereich. Die Figur rennt mit Laufanimation
und normaler Körperkollision dorthin (5 Meter/Sekunde), ohne Teleportation.
Partyzugehörigkeit entscheidet, nicht Angreifer/Verteidiger. Zielplätze werden
für bereits laufende Figuren reserviert.

Das lokale Wegenetz wird aus Boden- und Wandkollisionen erzeugt. Es unterstützt
die ebenen Bereiche der vorhandenen Levels; größere Höhenwechsel benötigen
zukünftig eine erweiterte Navigation. Ohne erreichbaren Zielplatz scheitert der
Fluchtversuch. Bleibt eine Figur zwei Sekunden stecken, kehrt sie in die
Zugvergabe zurück. Während des Rückzugs erhält sie keine Züge und ist kein
Angriffsziel. Das Kampfende wartet auf alle laufenden Rückzüge; danach gibt es
Steuerung und Kamera wieder frei, sobald eine Kampfseite ausgeschieden ist.

Für neue Levels `res://src/world/combat/flee_area.tscn` zweimal instanziieren
und `Destination Group` auf Party bzw. Gegner setzen. Die beiden vorhandenen
Zielgebiete sind jeweils 4 × 4 Meter groß (Höhe der Bodenprüfung: 4 Meter).

Die Entscheidung der Gegner-KI, bei Verletzungen zu fliehen, ist noch nicht
implementiert. Sobald sie `mark_fled()` aufruft, nutzt sie automatisch den
Gegnerbereich. Flucht zählt nicht als Sieg oder Tod des Gegners.

## Gemeinsame Kampfbewegung

`combat_grid.gd` definiert das nur während des Kampfes aktive 1-m-Raster.
`CombatSession.admit()` ordnet neue/zurückkehrende Figuren auf freie Zellmitten ein;
noch nicht in der Physik registrierte Figuren werden vor der Zugvergabe erneut
geprüft. `reachable()` liefert Position, vollständigen Weg und Kosten pro Feld.
Spieler und KI verwenden dieselbe Dijkstra-Suche mit acht Nachbarn, Körperprüfungen
und gesperrten diagonalen Ecken. Die gesamte Weglänge darf höchstens
`max(1, Gewandheit) × WorldUnits.METER` betragen. Berechnungen über 35 m werden
als Schutz vor übergroßen Suchnetzen abgewiesen. Kleine Höhenstufen sind durch
die Stufenhöhe begrenzt; komplexe Höhenwechsel bleiben offen.

`combat_grid_display.gd` zeigt das lokale Raster und die erreichbaren Felder an;
die Session besitzt und bereinigt die Anzeige. `StateCombatMove` lässt zunächst
ein Feld per Maus oder Bewegungstasten wählen. Abbrechen verändert keine Position.
Erst die Bestätigung prüft den Weg erneut und startet den physischen Wegfolger.
Während des Laufens ist kein Rückgängigmachen möglich.

`flee_route.gd.find_path()` und dessen optionale Radius-/Körperprüfung bleiben für
Flucht verfügbar. Außerhalb des Kampfes wird keine Position gerastert.

`character_path_motion.gd` führt Flucht und taktische Bewegung physisch aus.
Jeder Auftrag hat einen Besitzer; Abbruch durch einen alten KI-Auftrag stoppt
keine neu gestartete Flucht. Die KI wartet auf Ankunft oder Blockierung und
verbraucht damit einen Zug. Der Resolver bestätigt MOVE nur an der tatsächlichen
Position. Verhaltensprofile und Grenzen beschreibt das zentrale Design-Dokument
unter „KI-Werkzeuge und implementierter Nahkampf-Prototyp“.


Die KI kann einen gültigen Angriff zugunsten eines deutlich besseren Folgeangriffs
zurückstellen. Das Profil gewichtet dafür den entgangenen Angriff, den erwarteten
Trefferschaden und die tatsächliche Weglänge. Taktische Umwege müssen dasselbe
Raster-Wegbudget wie Spielerbewegung einhalten. Ein flüchtiger Cooldown im CombatParticipant verhindert
aufeinanderfolgende taktische Bewegungszüge bei weiterhin möglichem Angriff;
Wiedereintritt nach Flucht setzt ihn zurück. Bewegung und Angriff bleiben getrennte
Züge. Einzelheiten und Standardwerte stehen im zentralen Design-Dokument.

`test_combat_grid.tscn` prüft Eintritt/Rückkehr, Belegung, Wegkosten, diagonale
Ecken, Waffenreichweite, KI, Feldauswahl, Abbruch, dynamische Hindernisse und
die Rückkehr zur freien Bewegung. Mit `-- --preview-grid` erzeugt die Szene
zusätzlich eine gerenderte Vorschau unter `res://.combat-grid-preview.png`.

## Notwendige KI-Bewegung

Ohne möglichen Angriff plant `combat_ai_planner.gd` nötigenfalls über mehrere
Züge bis zu einer freien Angriffsposition. `combat_grid.gd.planning_routes()`
verwendet dieselben Hindernis-/Eckprüfungen; `approach_planning_distance` begrenzt
die Vorausschau auf standardmäßig 12 m Weglänge. Ein Schritt darf nie teurer als
ein einzelner Bewegungszug sein. Ausgeführt wird nur der Weganfang innerhalb
des normalen Budgets und `movement_search_radius`; `reachable()`/`find_path()`
erteilen weiterhin ausschließlich für den aktuellen Zug gültige Bewegung.

`npc_combat_turn.gd` aktualisiert Sichtbeobachtungen einmal pro eigener Planung.
`CombatParticipant.ai_last_seen` speichert nur Actor-Instance-IDs, letzte gesehene
Position und Alter, keine Referenzen auf andere Teilnehmer. Der Planner bleibt
ohne Seiteneffekte. Ohne sichtbaren Gegner kann die KI einen letzten Sichtkontakt
verfolgen; `target_memory_turns` begrenzt dies standardmäßig auf drei eigene Züge.
Keine verdeckten aktuellen Zielkoordinaten zur Planung verwenden. Ausscheiden,
Verfall und erfolgloses Erreichen entfernen Einträge; eigene Rückkehr nach Flucht
leert das Gedächtnis. Weltbewegung außerhalb des Kampfes und Save-Schema ändern
sich dadurch nicht.

`test_npc_navigation.tscn` prüft mehrzügige Umwege einschließlich notwendiger
anfänglicher Entfernung vom Gegner, kleine Zugbudgets, Folgeangriff, Sichtverlust,
Verfolgung, Gedächtnisverfall und unmögliche Bewegung (55 Prüfungen).
