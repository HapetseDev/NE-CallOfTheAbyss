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
