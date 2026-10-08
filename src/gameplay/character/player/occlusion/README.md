# Sichtfenster für die Party: dmlary VisualShader

Quelle: https://github.com/dmlary/godot-occlusion-cutout-demo
Stand: `ed1e3bbecd7d39833b50800205b8156d72cc2d52`.
Copyright 2024-present David M. Lary, MIT-Lizenz.
Originalshader, Rauschtextur und Lizenz liegen unverändert in `vendor/dmlary/`.

`party_cutout.tres` ist eine angepasste Kopie des originalen **VisualShader**
`textures/shader-fade-cutout.tres`, keine parallele Eigenimplementierung.
Der Graph verwendet weiterhin die Kapsel-SDF aus Expression 19, den additiven
Rauschrand sowie den Discard-/Bayer-Fade-Pfad des Originals. Die bisherige
`wall_cutout.gdshader` wird ersetzt.

## Projektspezifische Anpassungen

- `OcclusionVisual` unter `Party` verfolgt bis zu 64 sichtbare Mitglieder aus
  `get_all_members()`, unabhängig vom Anführer. Ein Strahltest vom Brustpunkt
  zur Kamera bestimmt den nächsten Treffer an `camera_occluder`-Geometrie.
  Charakterkörper werden ausgeschlossen. Bei orthografischen Kameras verlaufen
  die Strahlen parallel zur Blickrichtung.
- Expression 19 wertet je Mitglied eine Kapsel vom Kamerapunkt zum Wandtreffer
  aus. Arrays ersetzen die drei einzelnen globalen Parameter des Demo-Projekts.
  Die Radien blenden sich beim Auftreten eines Hindernisses ein.
- Laufboden bis 0,35 Einheiten über den Füßen und Flächen hinter den Figuren
  bleiben geschützt. Der originale `IN_SHADOW_PASS`-Schutz erhält Schatten.
- Expression 54 übernimmt die vorhandenen UVs, Texturen, Albedofarben,
  Rauheit, Metallic, Specular und Alpha-Scissor des Tilesets. Das lokale
  Projektionsmapping der Demo würde die vorhandenen UV-Texturen verändern.
- Die originalen Gebäude-Fade-Knoten sind enthalten, `fade` bleibt standardmäßig
  0. Die separate FadeArea3D-Gebäudelogik aus der Demo ist nicht eingebunden.

Radius (Standard 1,5) und Brusthöhe (0,7) werden an `OcclusionVisual` eingestellt.
GridMaps/Mesh-Unterbäume benötigen die Gruppe `camera_occluder` und passende
Physikkollisionen für den Strahltest. Beide Level markieren Wand-, Objekt- und
Boden-GridMaps. Laufzeitkopien schützen die Originalmaterialien und werden bei
Levelwechsel neu aufgebaut. Charaktere selbst erhalten keinen zusätzlichen
Leuchtpass; Glas und eigene Shader werden nicht konvertiert.

## Prüfung

`test_movement_cutout.tscn`: Partyzuordnung, Anführerwechsel, Materialisolation,
Wiederherstellung und echte Strahltests mit/ohne verdeckende Wand.
`test_cutout_render.tscn` benötigt Grafikausgabe und prüft den tatsächlichen
VisualShader mit zwei verdeckten Figuren, Kamerabewegung, Zoom, rückwärtiger
Wand, Obergeschoss und geschütztem Laufboden. Vergleichsbilder werden unter
`/tmp/necota-cutout-*.png` gespeichert.
