# Aufdeckbare Levelkarte

Der bestehende Kartenknopf in der oberen Leiste öffnet die Karte. Mausrad zoomt
am Mauszeiger, Ziehen verschiebt, „Übersicht“ passt alle entdeckten Bereiche ein.
Escape oder „Schließen“ schließt die Karte und gibt die eigene Eingabesperre frei.

`level_cartography.gd` liest den bereits geladenen Level: GridMap-Meshes samt
Zellrotation, MeshLibrary-Transformation und Welttransformation sowie sichtbare
MeshInstance3D-Nodes. Die X/Z-Projektion zeigt vereinfachte äußere Mesh-Umrisse
(konvexe Hüllen), keine Texturen oder Dreiecksnetze. Bodenflächen werden vereinigt,
um innere Kachelkanten auszublenden. GridMaps mit „Boden“/„Floor“ im Namen oder
boolescher Metadaten-Eigenschaft `map_floor = true` gelten als Boden.
Die Geometrie wird beim Levelwechsel aufgebaut; spätere Änderungen an statischen
Meshes benötigen einen erneuten Aufbau. Mehrere Stockwerke werden übereinander
projiziert; Terrain3D, CSG und Sprite-Geometrie werden noch nicht kartografiert.

Alle 0,2 Sekunden werden Zellen von 2 Welteinheiten im Radius von 8 Welteinheiten
um den Party-Leader entdeckt, auch bei geschlossenem Kartenfenster. Dies ist
räumliche Annäherung, keine Sichtlinienprüfung: Wände blockieren die Aufdeckung
aktuell nicht. Unbekannte Bereiche bleiben unbeschriebenes Papier. Kurze
Liniensegmente verhindern, dass ein großes Mesh durch eine entdeckte Ecke
vollständig sichtbar wird. NPCs, BasicItems und Interactable-Objekte erhalten
Punkte mit Namen. Außerhalb des Entdeckungsradius bleibt der zuletzt beobachtete
Standort erhalten. Als entfernt registrierte Weltobjekte verschwinden.

`papyrus_map.gd` zeichnet Papierfasern, gealterten Rand, Sepialinien, Markierungen
und Beschriftungen ohne zusätzliche Bilddatei. Alle Farben liegen als `MAP_*`
im zentralen NEColors-Tokensatz. Fenster und Buttons verwenden das globale Theme.

`WorldState.map_exploration` enthält pro Levelpfad entdeckte Zellschlüssel und
Markierungen (Weltposition, Name, Typ). Speicherformat **8** speichert und prüft
diesen Bereich. Versionen 1–7 werden mit leerer Kartenerkundung übernommen;
ein neues Spiel leert alle Kartendaten. Der Kartenstand ist unabhängig von der
bereits vorhandenen Liste besuchter Orte.

Prüfung: `res://src/debug/tools/test_map_ui.tscn` testet Fenster, Eingabesperre,
Geometrie, Entdeckung, letzte bekannte NPC-Position, Objektentfernung,
Speicherrundlauf, Altstandmigration, Levelwechsel und Neustart. Optional erzeugt
`-- --visual` mit aktivem Renderer `/tmp/necota-map-preview.png`.
