= Technische Grundlagen

== Frameworks

Bisher wird nur Godot in der Version 4.7 verwendet. Entwicklungssprache ist GDScript, offen ist der Umstieg auf CSharp, Version 10.

Möglicherweise wird für den Audiobereich ein weiteres Framework eingebunden.

Ziel ist es, nur OSS-Software zu verwenden.

== Builds

Zielplattformen sind wie folgt:

#table(
  columns: 2,
  table.header([Betriebssystem], [Plattform]),
  [*Windows*], [über Steam und GOG],
  [*Mac* ], [Über Steam und GOG, nur M-Prozessoren],
  [*Linux*],[ - Linux nativ als Appimage
  - Linux über Steam (für Steamdeck)
  - Ein Linuxbuild, damit es für Batocera zur Verfügung steht],
)


Nicht relevant aber schön wenn es irgendwie gehen würde:
#table(
  columns: 2,
  table.header([Betriebssystem], [Plattform]),
  [*FreeBSD*], [(Paketformat nicht bestimmt)],
  [*Haiku*], [(Paketformat nicht bestimmt)],
)


Ein Release auf Konsolen ist nicht geplant ebenso wie ein Release auf mobile Plattformen)