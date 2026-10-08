# Maussteuerung und Bodenhaftung

Linke Maustaste halten steuert weiter direkt in Richtung des Mauszeigers.
Die Entfernung bestimmt das Tempo; Tastatureingaben übernehmen die Steuerung.

`mouse_ground_picker.gd` beschränkt den Kamerastrahl auf ein Höhenband um die
Fußposition der gesteuerten Figur. Es überspringt nicht begehbare Wandtreffer,
ohne die ganze GridMap auszuschließen (Wände und Böden können denselben
Physikkörper besitzen). Falls nötig wird der Mauszeiger auf die aktuelle
Standhöhe projiziert und dort senkrecht nach einem echten Boden gesucht.
Ein gültiges Ziel behält seine tatsächliche Höhe. Ohne Boden gibt es kein
Bewegungsziel; ein alter Zielpunkt wird nicht weiter verfolgt.

Einstellungen im Inspector:

- `Player.mouse_floor_height_range`: Höhenband nach oben und unten, Standard 1,25.
  Auf Schrägen und Treppen wandert es mit der Figur mit. Es ist eine lokale
  Höhenheuristik, keine sichere Zuordnung überlappender Stockwerke; bei sehr
  engen Geschosshöhen den Wert reduzieren.
- `Playable.step_height`: maximale automatische Stufenhöhe, für Spieler und
  Begleiter standardmäßig 0,35, für andere Figuren 0 (deaktiviert).
- `floor_snap_length`: Spieler und Begleiter standardmäßig 0,4, damit sie
  beim Absteigen auf dem Boden bleiben.
- `floor_max_angle`: Godots maximale begehbare Neigung; steilere Flächen werden
  nicht als Boden akzeptiert.

`step_assist.gd` prüft bei Bodenkontakt eine niedrige Stufe vor der Kapsel,
deren begehbare Oberseite und die Kopffreiheit. Die normale Körperbewegung
übernimmt anschließend den horizontalen Weg. Sprünge erhalten keine Stufenhilfe.
Böden, Rampen und Treppen brauchen passende Kollisionsformen auf der
Kollisionsmaske der Figur. Hohe Absätze bleiben Hindernisse.

Die Steuerung plant keine Wege um Hindernisse. Für „einmal klicken und selbst
um Wände herum zum Ziel laufen“ wäre eine zusätzliche Navigation mit
NavigationRegion3D/NavigationAgent3D pro Level nötig.

Physiktest: `res://src/debug/tools/test_mouse_ground.tscn` — verdeckter Boden,
Etagenwahl, fehlender Boden, Treppe auf/ab, Wand, Schräge, Kopffreiheit und Sprung.
