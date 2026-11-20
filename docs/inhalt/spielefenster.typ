= Darstellung von Spielefenster

*Teilweise umgesetzt.* Gemeinsame Fenster, Partyreihenfolge, Charakterblätter, Inventare und Cover-Flow-Navigation existieren. Partygröße und Formation sind Ziele; der aktuelle Speichervertrag unterstützt nur Dannerman und Shalka.

Ein Spielefenster ist eine Ansicht für den Spieler, um den verschiedenen Erfordernissen des Spiels Herr zu werden.

== Normaler Spielüberblick

Für meiste Zeit des Spiels sieht der Spieler eine Übersichts des Spielfelds. Hier dargestellt mit Kuben, Zylinder und Strichfiguren. Über jeden Charakter, der der Party angehört ist ein kleines, halb-transparentes Fenster, mit einem Bild und der Anzahl der SP und KP. 

#align(center)[#image("../res/-Übersicht.png", width: 30%)]

Unten ist das halb-transparente Log-Feld, wo die Nachrichten an den Spieler angezeigt werden. Darunter ist die Spiel-Leiste. Bisher sind die folgende Punkte für die Leiste vorgesehen: 

- Party, zum Sortieren der Party-Reihenfolge (und später zum Einstellen einer Formation)
- Charakter, zum Aufrufen der Charakterblätter
- Inventar, zum Aufrufen des Paperdolls und des Gepäcks
- Karte
- Log
- Menü zum Speichern, laden, Beenden des Spiels und zum Aufruf der Optionen
- und für die Entwicklung ein Debug Menü.

== Grundsätzlicher Aufbau der Fenster

Die Fenster, welche Aufgerufen werden, sind angeordnet als "Cover Flow", was einer derartigen Sicht entspricht:

#align(center)[#image("../res/Cover-Flow.png", width: 30%)]

Das jeweilige Fenster, das aufgerufen wurde, wird in der Mitte angezeigt. Links und Rechts davon sind die jeweiligen Fenster der Leiste, wie sie in der Spiel-Leiste aufgelistet werden. 

Die Reihenfolge im Moment ist wie folgt: 

+ Party
+ Charakter
+ Inventar
+ Karte
+ Log
+ Menü
+ Debug 

Ist also das Fenster "Karte" aufgerufen, wird links angeschrägt von Rechts nach links "Inventar", "Charakter" und "Party" angezeigt, und rechts wird von links nach rechts "Log", "Menü" und "Debug" angezeigt. Es wiederholt sich dabei immer wieder, so dass links von "Party" "Debug" oder "Menü" angezeigt. Um die Fenster zu wechseln muss mit der Maus oder oder mit der Tastatur/Controller-Steuerung der Pfeil nach Links oder Rechts ausgewählt werden.

== Party Fenster

Das Partyfenster ist dazu gedacht, den Anführer zu bestimmen und auch die Reihenfolge der Party. 

#align(center)[#image("../res/-Party-Übersicht.png", width: 30%)]

Das Fenster kann bis nach unten gescrollt werden, da die Anzahl an Partymitgliedern nicht beschränkt ist.

== Charakter Fenster

Das Charakterfenster zeigt die Charakterblätter aller Charakter in Reihenfolge, wie sie im Party Fenster festgelegt wurde.

#align(center)[#image("../res/-Charakter.png", width: 30%)]

Die Charakterblätter können durchgescrollt werden. Sobald ein Charakterblatt eines Charakters zuende ist, wird das nächste direkt darunter angezeigt.

== Inventar Fenster

Von der Bedienung ist das Inventar-Fenster genauso zu behandeln wie das Charakterfenster. Hier wird jedoch das Inventar angezeigt. Mit Drag und Drop über Maus oder mit einem Aktionsmenü ausgerüstet werden. 

#align(center)[#image("../res/-Inventar.png", width: 30%)]

Gegenstände können über Kontextmenü oder über Drag and Drop an andere Charakter weitergegeben werden, da ein Inventar eines Charakters überhalb des Inventars eines anderes Charakters durchgescrollt werden kann.

== Verbindlicher Weltmaßstab

*Implementiert:* Eine Godot-3D-Welteinheit entspricht genau *einem Meter*.
Die gemeinsame Definition ist `WorldUnits.METER` in
`src/core/world/world_units.gd`. Positionen, Radien, Waffenreichweiten und
Bewegungsdistanzen werden in Metern angegeben, Geschwindigkeiten in Metern pro
Sekunde. Der Maßstab ist ein fester Vertrag, kein Balancing-Regler; für andere
Reichweiten werden die jeweiligen Meterwerte geändert. Kamera-Zoom und
Sprite-Skalierung ändern die physische Entfernung nicht. Neue Modelle und
Kollisionsformen sind in diesem Maßstab anzulegen; bestehende Levels werden
nicht nachträglich skaliert. Gespeicherte Positionen bleiben unverändert gültig.

Aktuell verwenden Interaktionen standardmäßig 1,5 m Radius und die Reaktion auf
Kampfaufnahme 8 m Radius. Im Kampf gilt ein Raster mit 1 × 1 m großen Zellen.
Das Bewegungsbudget beträgt einen Meter pro effektivem Gewandheitspunkt
(mindestens 1 m), bei 1 m/s Bewegungstempo. Es begrenzt die gesamte Weglänge:
gerade Schritte kosten 1 m, diagonale etwa 1,41 m. Interaktionen messen auf der XZ-Ebene; die
Kampfaufnahme verwendet weiterhin die räumliche 3D-Entfernung.

*Implementiert:* Gegenstandsangriffe prüfen die räumliche 3D-Entfernung zwischen
Actor-Ursprüngen vor Schaden und Verbrauch. Nahkampfmodi ohne explizite Angabe
verwenden 1,5 m; Messer- und Steinwurf 10 m. Neue Waffen:

#figure(
  table(
    columns: 4,
    table.header([Gegenstand], [Reichweite], [Kampfwert], [Besonderheit]),
    [Dolch], [1 m], [6], [Kurze Klingen],
    [Schwert], [2m], [8], [Schwertkampf (klassisch)],
     [Speer], [3m], [8], [Stoßangriff],
    [Bogen], [20m], [7], [Bogenschießen; ein Pfeil aus dem Rucksack pro Schuss],
  ),
) <texpile-table-862f714063b2>




Die Ressourcen liegen unter `src/resources/items/`, die aufhebbaren Szenen unter
`src/world/objects/items/` (jeweils `dolch`, `schwert`, `speer`, `bogen`, `pfeil`).
Sie verwenden gemeinsame 3D-Waffenansichten (siehe folgenden Abschnitt)
und sind noch nicht in Levels platziert. Pfeile sind stapelbare eigene Gegenstände. Der Bogen bleibt nach dem
Schuss erhalten; ein ausgewichener Schuss verbraucht ebenfalls einen Pfeil.
Bei fehlender Munition, Reichweite oder Sicht erfolgt kein Verbrauch.
Die Werte sind erste Balancingwerte, keine Simulation historischer Waffen.

=== Waffenformen und sichtbare Handausrüstung

*Implementiert:* `src/resources/items/item_visual.gd` erzeugt die gemeinsame
reine 3D-Ansicht für Weltgegenstände und Handausrüstung. Für passende Waffen
verwendet sie Meshes aus dem gelieferten Paket `Poly-Survival Melee Weapons`:

#table(
  columns: 2,
  table.header([Gegenstand], [Modell im Quellpaket]),
  [Schwert], [`SM_Handcrafted_Sword`],
  [Dolch], [`SM_Handcrafted_Knife_02`],
  [Messer], [`SM_Handcrafted_Knife_01`],
)

Das Paket enthält 57 Modelle; Speer, Bogen und Pfeil besitzen keine passende
Entsprechung und behalten ihre prozeduralen Ansichten. Die aufbereiteten Meshes
liegen komprimiert mit eingebettetem Texturatlas unter `assets/items/weapons/`.
Die ursprünglichen Demo-Positionsversätze und Verweise auf fehlende
`NewPallet_v1.png`-/`res://Assets/…`-Pfade werden nicht übernommen. Der unveränderte
Quellbestand wird per `.gdignore` von automatischem Godot-Import und Export
getrennt; die verwendeten Spielressourcen liegen außerhalb dieses Ordners.

Dolch, Schwert und Speer haben weiterhin eine Gesamtlänge von 1, 2 bzw. 3 Metern
entsprechend ihrer Nahkampfreichweite. Beim Messer gelten 1,5 m, nicht die 10 m
Wurfweite; der Pfeil ist 1 m lang. Der Bogen bleibt ungefähr 1,2 m groß statt
seiner 20 m Schussreichweite. Die Meshes werden gleichmäßig skaliert und behalten
ihren Ursprung im Griff für die Handbefestigung. Ablegen gleicht die tatsächliche
Modellunterkante aus; die Kollisionsbox umfasst die sichtbare Form. Die Werte
sind bewusst spielerische Darstellungsvorgaben.

Alle sechs Waffen besitzen aus derselben Ansicht gerenderte, transparente
256×256-PNG-Inventarbilder unter `assets/items/weapons/icons/`. `ItemData.icon`
versorgt Rucksack, Hand- und Schnellplätze. Die größere Gegenstandsansicht im
Inventar zeigt beim Auswählen/Hovern dasselbe Bild und leert sich bei leerer
Auswahl. PNG-Pfade funktionieren mit dem bestehenden Save-Codec; es gibt keine
Schemaänderung. Alte Speicherstände mit `icon=null` erhalten die Waffenbilder
über ihre stabile Item-ID ebenfalls. `icon` und `world_texture` werden auch bei tiefen Registry-Kopien
als unveränderte Bildassets geteilt, damit ihr stabiler Resourcepfad erhalten bleibt.

Reproduzierbare Werkzeuge: `import_survival_weapon_models.tscn` bereitet die drei
Quellmodelle auf; `render_weapon_icons.tscn` rendert die sechs Bilder mit einem
normalen Rendering-Treiber (nicht `--headless`). Beide liegen unter
`src/debug/tools/`. `test_weapon_models.tscn` prüft Modellwahl, Texturen, Länge,
Weltkollision, Icons, Inventarausrüstung, tiefe Kopien und vollständige Weltstände
(84 Prüfungen). Die Vorschau wurde zusätzlich im gerenderten Inventar kontrolliert.
Inventarlayout (50), Kampf-Ausrüstung/Musik (30) und Handausrüstung (36) bestehen
ebenfalls. Registry-Prüfungen bestehen mit 116 Checks, melden aber weiterhin den
bereits bekannten HUD-Kartenfehler beim Wechsel ins Hauptmenü. Der abschließende
Projektimport samt Script-UIDs ist erfolgreich; eine Warnung über ein weiteres
`project.godot` im neu hinzugefügten FantasyVillage-Assetpaket bleibt außerhalb
dieser Änderung. Ältere `/tmp/`-
Testpfade wurden nur in temporären Windows-Testkopien angepasst.

`held_item_visuals.gd` verbindet `primaer_hand` mit `RightHand` und `nebenhand`
mit `LeftHand` des vorhandenen Skeleton3D. BoneAttachment3D führt die Ansicht
mit der animierten Hand mit. Die GLB-/Armature-Skalierung wird kompensiert,
damit die Waffe ihre Größe in Weltmetern behält. Für Modelle ohne passende
Handknochen gibt es einen einfachen positionsbasierten Fallback.

Inventarsignale und Charakter-Neubindung aktualisieren die Ansicht. Wechsel,
Ablegen, Wurfverbrauch und Bruch entfernen das bisherige Modell; Handplätze
sind voneinander unabhängig. Rucksack und Schnellplätze erzeugen keine
Handansicht. Andere Gegenstände nutzen vorhandene Texturen, andernfalls eine
neutrale Ersatzform. Es werden keine ItemData-Kopien, Weltobjekt-IDs oder
Physikkörper für gehaltene Gegenstände angelegt und keine Visual-Nodes gespeichert.

Aufhebbare Weltwaffen erhalten dieselbe Ansicht sowie eine aus den tatsächlichen
Modellgrenzen abgeleitete Kollisionsbox. Die sichtbare Handwaffe verändert keine bestehenden
Angriffs-, Reichweiten- oder Trefferzonenregeln. Zweihandpflicht, spezielle
Greifposen, Spann-/Schussanimationen und fliegende Projektile bleiben offen.

`test_held_weapons.tscn` prüft die tatsächlichen Mesh-Ausmaße, beide Handknochen,
Maßstab, Ausrüstungswechsel, Verbrauch und fehlende persistente Duplikate.

=== Angriffslinie und Abfangen von Waffenangriffen

*Implementiert:* Bei Gegenstandsangriffen (Bogen, Wurf- und Nahkampfwaffen,
auch improvisierte Schläge) bestimmt eine 3D-Linie zwischen den Profil-Zielpunkten die erste Trefferform
zwischen Angreifer und gewähltem Ziel.
Der Angreifer ist ausgeschlossen. Die erste aktive Figur der laufenden
CombatSession erhält den Angriff, unabhängig von ihrer Kampfseite: Auch
Verbündete und neutrale Teilnehmer können getroffen werden. Wände stoppen den
Angriff; eine Figur vor einer Wand wird zuerst getroffen. Figuren außerhalb der
Session sowie ausgeschiedene Körper blockieren weiterhin, erhalten aber keinen
neuen Schaden. Es werden keine zusätzlichen Charakterdaten oder Teilnehmer erzeugt.

Die Waffenreichweite wird vor dem Angriff sowohl zum gewählten Ziel als auch
zum tatsächlichen Empfänger geprüft. Ein naher Abfänger erlaubt keinen Angriff
auf ein gewähltes Ziel außerhalb der Reichweite. Ein solcher Versuch schlägt mit
`out_of_range` fehl, ohne Schaden, Munition, Wurfgegenstand oder Bruchprüfung.
Ausweichen, Rüstung und Niederlage beziehen sich auf den tatsächlichen Empfänger. Der Angriff endet auch bei Ausweichen am ersten Körper;
es gibt kein Durchschlagen. Ein ausgeführter Bogenschuss verbraucht genau einen
Pfeil. Eine blockierte oder zu lange Angriffslinie verbraucht keine Munition.

Die Waffen-Zielwahl zeigt bei Hover bzw. Tastaturfokus die Angriffslinie und
nennt im Zielknopf den ersten Empfänger. Ein Abfänger sperrt die Aktion nicht.
Die endgültige Trefferprüfung erfolgt erneut beim Ausführen. Die Vorschau wird
bei Menüwechsel, Zugende und Szenenabbau entfernt. Die Gegner-KI nutzt dieselbe
Trefferermittlung; taktisches Vermeiden eigener Verbündeter bleibt offen.
Fähigkeiten und Heilung behalten ihre bisherigen Ziel-/Sichtregeln. Die Linie
ist eine gerade Angriffsbahn, noch keine Projektilflugkurve oder Schwertschwingfläche.

Prüfung: `res://src/debug/tools/test_attack_vectors.tscn` testet echte
Körperkollisionen, Abfangreihenfolge, Seiten/Höhen, Wände, Reichweite,
Munition, Ausweichen, Niederlage und die Menüvorschau samt Bereinigung.

Nahkampffähigkeiten einschließlich Fausthieb prüfen ebenfalls ihre Reichweite
(Standard 1,5 m), bevor Konzentration verbraucht wird.

Die Ziel- und Trefferstellenbuttons zeigen zu weit entfernte Ziele mit roter
Schrift (`NEColors.DANGER`), Waffen-/Aktionsname und maximaler Reichweite an;
sie sind gesperrt. Der Angriffsresolver prüft unabhängig von der Anzeige erneut,
auch nach einer Positionsänderung. Die Angriffsvorschau kennzeichnet eine zu
lange Linie ebenfalls rot.

*Noch offen:* Reichweiten von Fernkampf-/Magiefähigkeiten,
Projektilanimationen und Zweihandpflicht. Taktisches Annähern nutzt jetzt den
LimboAI-Nahkampf-Prototyp (siehe KI-Werkzeuge).
Der Wahrnehmungsradius bei Kampfaufnahme ist noch kein allgemeines Wahrnehmungssystem.

== Angriffe, Gegenstandseigenschaften und Musik

*Umgesetzt mit ausdrücklich genannten Übergangsregeln.* Die Unterpunkte zu späterer Entwicklung sind weiterhin geplant, keine aktuellen Fähigkeiten.

=== Waffenlose Angriffe

Ein Charakter kann auch ohne Gegenstand angreifen. Bei mindestens einer freien Hand erscheint im Kampfmenü die Aktion *Schlag*. Sie ist außerdem über das Fähigkeitenmenü verfügbar.

Die Angriffsstärke berechnet sich aus:

*Effektive Körperkraft + abgerundete Hälfte der Fertigkeitsstufe „Waffenloser Kampf“*

Die effektive Körperkraft enthält weiterhin die vollständigen Attributboni gelernter Fertigkeiten. Nur der zusätzliche, unmittelbar auf den Angriff angerechnete Fertigkeitsbonus wird halbiert.

Beispiele für den zusätzlichen Bonus:

- Fertigkeitsstufe 1: +0
- Fertigkeitsstufe 2 oder 3: +1
- Fertigkeitsstufe 10: +5

=== Angriffe mit Gegenständen

Jeder Gegenstand kann als Angriffsgegenstand verwendet werden. Für die Kampfnutzung muss er in einer Hand oder einem Platz der Schnellausrüstung liegen. Gegenstände ohne eigene Angriffsart bieten einen improvisierten Schlag an.

Die Angriffsstärke berechnet sich aus:

*Effektive Körperkraft + Kampfwert des Gegenstands + abgerundete Hälfte der passenden Fertigkeitsstufe*

Jeder Gegenstand besitzt mindestens den *Kampfwert 1*. Fehlt eine passende gelernte Fertigkeit, beträgt der zusätzliche Fertigkeitsbonus 0.

Beim Messer wird die Körperkraftfertigkeit *Kurze Klingen* angerechnet. Gegenstände können unterschiedliche Kampfwerte für ihre Verwendungsarten besitzen. Das Messer verwendet derzeit Kampfwert 6 beim Stechen und Kampfwert 8 beim Werfen.

=== Verteidigung, Mindestschaden und Rüstung

Nach Berechnung der Angriffsstärke werden Ausweichen und Schadensminderung durch Robustheit angewendet.

Ein erfolgreicher Treffer mit positiver Angriffsstärke verursacht *mindestens 1 Schaden, wenn die getroffene Stelle ungerüstet ist*. Ein ausgewichener Angriff verursacht weiterhin 0 Schaden.

Bei einer gerüsteten Trefferstelle darf der Schaden vollständig abgefangen werden. Nullschäden bleiben damit ein gewollter Bestandteil des Kampfsystems. Schwachpunkte sollen später Möglichkeiten schaffen, wirksame Angriffe gegen ansonsten gut geschützte Gegner auszuführen.

*Umgesetzt:* Trefferzonen und örtliche Rüstung werden gemäß den folgenden Körperprofil-Regeln ausgewertet. Normale Kleidung sowie Rüstung im Rucksack oder in der Schnellausrüstung schützen nicht automatisch.

Die Rüstungskennzeichnung bestimmt den örtlichen Mindestschaden; zusätzliche Schadensminderung wird pro Zone und Schadensart aus natürlichem Schutz und Rüstungswerten berechnet.

=== Körperprofile, Trefferzonen und richtungsabhängige Verwundbarkeit

*Implementiert als erste Ausbaustufe.* Körperbau, Angriffsrichtung und Schutz
werden im bestehenden CombatResolver ausgewertet. Alle Zonen teilen weiterhin
die Lebens-/Stärkepunkte der CharacterResource. Es gibt keine zweite
Schadensbuchhaltung und keine individuellen Gliedmaßenverletzungen.

==== Gemeinsame Körperprofile

`CharacterResource.body_profile_id` wählt `human`, `beetle` oder `animal`.
Die gemeinsamen Profilressourcen liegen unter `src/resources/combat/bodies/`;
`body_profile.gd` und `body_zone.gd` definieren ihre Datenverträge.
Die Definitionen werden zur Laufzeit gelesen, nicht pro Figur verändert.
Bestehende Figuren und ältere Spielstände erhalten das Menschenprofil.
Weitere Arten benötigen ein neues Profil und dessen Freigabe im Profilkatalog;
eine automatische Ableitung aus Namen oder Spezies findet nicht statt.

#table(
  columns: 3,
  table.header([Profil],[Trefferzonen], [Erste Balancingwerte]),
  [Mensch], [Kopf, Rumpf, Ober-/Unterarme, Beine und Füße, Gliedmaßen links/rechts getrennt], [Kopf ×1,75; Rumpf ×1; Unterarm ×0,65],
  [Gepanzerter Käfer], [Kopf, Rückenschild, Bauch, linkes/rechtes Beingelenk], [Rückenschild ×0,9 mit natürlichem Schutz; Bauch ×1,4 ohne Panzer],
  [Ungerüstetes Tier], [Kopf, Rumpf, Bauch, vier Beine], [Kopf ×1,6; Rumpf ×1; kein natürlicher Rüstungsabzug],
)



Eine Zone besitzt eine stabile ID, Bezeichnung, lokale Trefferbox in Metern,
Schadensfaktor, natürlichen Schutz und passende Körper-Ausrüstungsplätze.
Die Boxen folgen Position und Blickrichtung der Figur (+Z vorne, +Y oben).
Sie sind separate rechnerische Trefferformen; die Bewegungskapsel bleibt
unverändert. Sie sind auf die derzeitigen Prototypkörper abgestimmt und noch
nicht an animierte Skelettknochen gebunden.

==== Räumliche Zielwahl und Abfangen

Bei Waffen wird nach dem Ziel eine Trefferstelle gewählt. Die Vorschau führt
vom Standard-Zielpunkt des Angreifers zum Mittelpunkt der gewählten Zone.
Der Resolver prüft dieselbe Linie erneut und verwendet die erste geschnittene
Profil-Trefferbox. Daher kann eine andere Zone oder ein anderer Kampfteilnehmer
als angezielt getroffen werden. Die körperliche Abfangreihenfolge und Wände
bleiben maßgeblich; die Bewegungskapseln registrierter Teilnehmer ersetzen die
Profilboxen dabei nicht. Ein durch Deckung verdeckter Rumpf verhindert nicht die
Auswahl einer anderen erreichbaren Zone. Reichweite und Munition werden weiter
vor der Schadensauflösung geprüft.

Schadensfähigkeiten verwenden ohne explizite Zielzone die Standardzone des
Empfängers. Ihre bisherigen Ziel- und Sichtregeln bleiben bestehen. Fausthieb
verursacht Wuchtschaden. Heilung verwendet keine Verwundbarkeitsmultiplikatoren.

==== Richtung und Abwehr

Vorne, Seite und hinten ergeben sich aus der Blickrichtung des tatsächlich
getroffenen Lebewesens und der horizontalen Richtung zum Angreifer. Ein
Skalarprodukt ab 0,5 gilt als vorne, bis −0,5 als hinten, dazwischen als Seite.
Bei horizontal gleicher Position gilt vorne. Die Abwehr-Gewandheit wird derzeit
vorne mit 1, seitlich mit 0,6 und hinten mit 0,25 gewichtet; Genauigkeit und die
bestehende Ausweichobergrenze werden anschließend wie bisher angewendet.
Die Faktoren stehen im Körperprofil und sind artspezifisch änderbar.

Es gibt keinen pauschalen zusätzlichen Rückenschadensbonus. Der tatsächliche
Schutz der getroffenen Zone bleibt ausschlaggebend, sodass ein Käferrücken trotz
eingeschränkter Abwehr stark geschützt sein kann. Parieren ist noch nicht
implementiert.

==== Schutz pro Zone und Schadensart

Wucht (`blunt`), Schnitt (`slash`), Stich (`pierce`) und Magie (`magic`) sind
explizite Schadensarten von Waffen-Verwendungsarten bzw. Fähigkeiten.
Natürlicher Schutz und der richtungsabhängige Schutz angelegter Rüstung werden
pro Schadensart und Trefferzone addiert.
Der Käfer-Rückenschild mindert beispielsweise Wucht um 4, Schnitt um 8 und Stich
um 6; sein Bauch hat keinen solchen Abzug. Die Werte sind Balancing-Startwerte.

`ItemData.armor_zones` legt explizite geschützte Zonen fest. Bei leerer Liste
bestimmt der angelegte Körperplatz die Abdeckung gemäß Profil. Nur als Rüstung
gekennzeichnete Gegenstände an Kopf, Rumpf, Beinen oder Füßen zählen;
Rucksack, Hände, Schmuck und Schnellausrüstung gewähren diesen Schutz nicht.
`armor_protection` enthält die Abzüge je Schadensart. Die Beispielressourcen
`lederhelm.tres` und `lederweste.tres` schützen Kopf bzw. Rumpf. Das Inventar
zeigt Abdeckung, Schutzwerte sowie Schadensarten und Reichweiten der Angriffe.

==== Blickrichtung nach Angriffen

Ausgeführte Waffenangriffe, Fausthiebe und Schadensfähigkeiten richten den
Angreifer zum tatsächlichen Trefferempfänger aus. Das gilt auch bei Ausweichen
oder vollständig abgefangenem Schaden. Die gemeinsame Auflösung im
CombatResolver übernimmt dies für Spieler, Begleiter und NPCs; der KI-Runner
benötigt keine eigene vorherige Drehung. Bei mehreren Empfängern bleibt die
Richtung zum zuletzt aufgelösten gültigen Empfänger erhalten.

Zielvorschau, abgelehnte Angriffe und Heilung ändern die Angriffsrichtung nicht.
Getroffene Figuren drehen sich nicht automatisch zum Angreifer. Wartestatus und
Zugende setzen die Blickrichtung nicht zurück; reguläre Bewegung setzt weiterhin
die Laufrichtung. `face_world_position()` aktualisiert Modell, Kardinalrichtung
und bei Änderungen das vorhandene `direction_changed`-Signal. Die Methode
unterstützt auch Simulations-Actors außerhalb des Szenenbaums. Für gleiche
XZ-Position bleibt die vorhandene Richtung erhalten. Es gibt keine zusätzlichen
persistenten Felder oder Änderungen am Speicherformat.

`test_combat_facing.tscn` prüft 12 Fälle einschließlich echtem Spielerzug,
Zielvorschau, Modelldrehung, Signal, passivem Verteidiger, Wartestatus,
Reichweiten-/Munitions-/Konzentrationsfehlern, ausgewichenem Fähigkeitsangriff,
Heilung und gleicher Position. NPC-KI (36), Richtungsrüstung (32) und Trefferzonen
(58) bestehen ebenfalls. Projektimport, Klassenindex und Script-UID sind geprüft.

==== Richtungsabhängige menschliche Rüstung

Getragene Rüstung wird innerhalb der tatsächlich getroffenen Körperzone nochmals
nach der vorhandenen Angriffsrichtung gewichtet. Menschliche Körperprofile nutzen
standardmäßig *vorne 100 %, seitlich 75 %, hinten 50 %*. Natürlicher Schutz und
Robustheit erhalten diesen Faktor nicht. Andere Körperprofile behalten ohne
explizite Item-Overrides gleichmäßige getragene Rüstung; der natürliche
Käfer-Rückenschild bleibt damit unverändert stark.

Die Berechnung bleibt ein multiplizierter Abzug, ohne zusätzlichen Würfelwurf:

`örtlicher Schutz = natürlicher Schutz + runden(Summe der passenden Rüstungsteile × jeweiligem Richtungsfaktor)`

Beispiel für ein Rüstungsteil mit Schnittschutz 8: vorne 8, seitlich 6, hinten 4.
Anschließend gelten die bisherigen Zonenfaktoren, Robustheit und Mindestschadens-
regeln. Die gemeinsame Front-/Seite-/Rücken-Erkennung verwendet weiterhin das
Skalarprodukt zur Blickrichtung mit den Grenzen +0,5 / −0,5. Der tatsächliche
Trefferempfänger bestimmt Blickrichtung und Schutz, auch bei einem Abfänger.

`ItemData.armor_direction_factors` erlaubt je Rüstungsteil die optionalen Schlüssel
`front`, `side`, `rear`; fehlende Einträge nutzen die Profilstandards. Zulässig sind
endliche Zahlen von 0 bis 2. Beispiel: `{"front": 1.25, "side": 0.5, "rear": 0.0}`.
Faktor 0 bedeutet aus dieser Richtung keine Abdeckung durch dieses Rüstungsteil;
bei sonst fehlendem Schutz gilt der ungerüstete Mindestschaden. Grundschutz und
Abdeckung stehen weiterhin in `armor_protection` und `armor_zones`. Die Werte
werden im Inventar mit den wirksamen Prozentfaktoren erläutert.

Der Resolver und die KI nutzen dieselbe Schutzfunktion. Die KI bewertet auch
geplante Standorte mit deren künftiger Angriffsrichtung, ohne Actors dafür zu
versetzen. Bestehende Ausweichregeln bleiben zusätzlich wirksam.

Speicherformat *14* enthält das neue Faktor-Dictionary. Writer, Reader und
Validierung sind gemeinsam angepasst. Versionen 1–13 erhalten fehlende Dictionaries
als leer und damit die neuen Standardfaktoren; vorhandene Grundschutzwerte bleiben
erhalten. Unbekannte Richtungen, negative/zu große/nicht endliche Faktoren und
fehlende neue Felder in Version 14 werden abgelehnt. Fehlgeschlagenes Schreiben
erhält den letzten gültigen Spielstand.

`test_directional_armor.tscn` besteht mit 32 Prüfungen für Front/Seite/Rücken,
Drehung, örtliche Abdeckung, Item-Overrides, Faktor 0, natürlichen Käferschutz,
Rundung, geplante KI-Positionen, Inventartext, Validierung und vollständige
Speicherrundläufe einschließlich Version-13-Migration. Rüstung (55), Trefferzonen
(58), NPC-KI (36) und Waffenmodelle (84) bestehen ebenfalls. Die Inventaranzeige
wurde zusätzlich gerendert und kontrolliert. Inventar (50) und Kampfausrüstung
(30) bestehen ebenfalls. Der Klassenindex ist aktualisiert; ein zusätzlicher
Editorlauf lief beim Wiederöffnen vorhandener Szenen ins Zeitlimit.

==== Rüstungsgegenstände aus vorhandenen Assets

Aus `POLY_MedievalCamp/AnimpicStudio/POLY - Medieval Camp/Models/Helmet.gltf`
werden die vorhandenen Meshes `helmet` und `broken helmet` verwendet. Die übrigen
geprüften Modelle enthalten keine passenden eigenständigen Brustpanzer oder
Kettenhemden; der vorhandene Bowler-Hut zählt nicht als Rüstung. Das Schild wird
nicht als passiver Handschutz hinzugefügt, da dafür eigene Kampfregeln fehlen.

#table(
  columns: 5,
  table.header([Gegenstand], [Gewicht],[ Wucht / Schnitt / Stich ],[Kauf / Verkauf],[Anfangsbestand]),
  [Eisenhelm], [1,8], [2 / 5 / 3], [45 / 20 Gold], [2],
  [Beschädigter Eisenhelm], [1,6], [1 / 2 / 1], [15 / 5 Gold], [1],
)


Beide belegen `kopf` und schützen ausschließlich `head`. Die beschädigte Variante
ist eine eigene Definition mit schwächerem Schutz; es gibt keine neue Haltbarkeits-
oder Reparaturmechanik. Gewichte, Preise und Schutzwerte sind erste Balancingwerte.
Die bisherigen Lederbeispiele bleiben erhalten. Die neuen Helme gibt es beim
Wanderhändler in neuen Spielen. Bereits gespeicherte Händlerbestände werden wie
bisher unverändert geladen und erhalten nicht automatisch neue Angebote.

Definitionen: `src/resources/items/eisenhelm.tres` und
`beschaedigter_eisenhelm.tres`. Aufhebbare Szenen liegen unter
`src/world/objects/items/`. Die aufbereiteten Meshes und transparenten PNG-Icons
liegen unter `assets/items/armor/`; Originalassets bleiben unverändert. Der Import
repariert den Atlaspfad zu `MainTexture_01.png` und übernimmt die vorhandene
Ausrichtung des Modells in die Mesh-Geometrie. `import_armor_models.tscn` und
`render_armor_icons.tscn` unter `src/debug/tools/` können diese Ressourcen erneut
erzeugen. Der gemeinsame Icon-Renderer besitzt dazu konfigurierbare Gegenstände,
Ausgabepfad und Ansichtswinkel; die bisherige Waffenkonfiguration bleibt Standard.

Die gemeinsame Item-Ansicht zeigt dieselben Modelle beim Ablegen, im Inventarbild
und beim Ausrüsten. Der bisherige Handausrüstungs-Controller führt zusätzlich
einen `Head`-Socket. `headfront`/`head_end` bestimmen die Helmmitte, falls vorhanden;
BoneAttachment3D übernimmt die Bewegung. Importskalierung wird kompensiert.
Actors ohne passenden Knochen verwenden die Kopfposition des Körperprofils.
Wechsel, Ablegen, Charakter-Neubindung und Szenenabbau entfernen eigene Ansichten.
Nur angelegte Kopfplätze verleihen Schutz; Tragen in Hand, Rucksack oder
Schnellausrüstung wirkt weiterhin nicht als Kopfrüstung. Lange Haare können durch
den Helm ragen, da Frisuren derzeit im Charaktermesh enthalten sind. Die statische
Inventar-Paperdoll wird nicht neu gerendert; Slotbild und Gegenstandsansicht zeigen
den Helm. Speichern verwendet die bestehenden Item-/Shopverträge und das oben
beschriebene aktuelle Schema 14.

`test_armor_models.tscn` prüft 55 Fälle für Schutz, tatsächlichen Schaden, fehlenden
Schutz anderer Zonen/Plätze, Modell/Icon, Weltkollision, Shopkauf, beide Party-Rigs,
Kopfmarkierungen, Fallback, Ablegen und Speichern/Laden. Gerenderte Inventar- und
Charakteransichten wurden zusätzlich kontrolliert. Waffenmodelle (84) und
Handausrüstung (36) bestehen ebenfalls. Der vorhandene Händlertest enthält drei
veraltete Erwartungen an Inventargrößen von 1 bzw. 2 Slots; die seit der
Waffenerweiterung größeren Startinventare verletzen diese Annahmen. Die neuen
Helm-Käufe und Bestände werden im Rüstungstest gezielt geprüft. Trefferzonen
bestehen mit 58 Prüfungen. Der erste Projektimport der neuen Helm-Bilder war
erfolgreich; eine zusätzliche abschließende Importwiederholung lief ins Zeitlimit.
Die neuen Script-UIDs sind vorhanden und die Laufzeitszenen sind geprüft.

Der Schaden ist zunächst gerundete Angriffsstärke × Zonenfaktor, abzüglich der
bestehenden Robustheitsminderung und des örtlichen Schutzes. Ein erfolgreicher
positiver Angriff verursacht an einer ungeschützten Zone mindestens 1 Schaden;
örtliche Rüstung oder wirksame natürliche Panzerung dürfen ihn vollständig
abfangen. Die frühere Regel „ein Rüstungsteil macht die ganze Figur gerüstet“
ist damit ersetzt. Das Ergebnis/Log nennt die tatsächlich getroffene Zone und
Angriffsrichtung; Niederlagen betreffen weiterhin den wirklichen Empfänger.

==== Speicherung, Prüfung und Grenzen

Seit Speicherformat 13 sind Profil-ID, Rüstungsabdeckung/-schutz und die
Schadensart der ItemUsageMode enthalten. Versionen 1–12 ergänzen fehlende Profil-IDs mit
`human`, Rüstungsfelder mit leeren Listen/Schutzwerten und Schadensarten mit
`blunt`. Bestehende Werte bleiben erhalten; eine Umdeutung alter Waffen anhand
ihres Namens erfolgt nicht. Neue Vorlagen setzen ihre Schadensarten ausdrücklich.
Reader und Validierung lehnen unbekannte Profile, Schadensarten, Zonen sowie
ungültige Schutzwerte ab. Trefferboxen, Nodes und laufende Angriffe werden
nicht gespeichert.

`test_combat_anatomy.tscn` prüft Profile, Trefferzonen, Richtungen, Abwehr,
örtlichen Schutz, Schadensarten, räumliche Treffer und Speicher-Migration.
Die bestehenden Tests für Angriffslinien, Waffenreichweiten, Schaden, Weltzustand,
Laden und Kampfsimulation bleiben Integrationsprüfungen.

Offen bleiben animierte Trefferformen, individuelle Gliedmaßenverletzungen,
zerstörbare Panzerplatten, weitere Arten und das Feintuning der Zahlen.

=== Inventaranzeige und Gegenstandsbruch

Ein Kampfwert von 1 wird in den Gegenstandseigenschaften nicht angezeigt. Höhere Kampfwerte und unterschiedliche Werte einzelner Verwendungsarten werden ausgewiesen.

Für jeden Gegenstand kann eine *Bruchchance zwischen 0 und 100 Prozent* festgelegt werden. Standardmäßig beträgt sie 0 Prozent.

Die Bruchchance wird einmal nach einem ausgeführten Gegenstandsangriff geprüft, auch wenn das Ziel ausgewichen ist. Wird kein gültiges Ziel angegriffen, findet keine Bruchprüfung statt.

Zerbricht ein Gegenstand, wird das verwendete Exemplar aus dem Ausrüstungsplatz entfernt. Gleichartige Gegenstände im Rucksack bleiben erhalten. Geworfene oder anderweitig verbrauchte Gegenstände werden nicht zusätzlich auf Bruch geprüft.

Damit lassen sich beispielsweise Glasflaschen als verwendbare, aber zerbrechliche Angriffsgegenstände definieren.

=== Levelmusik

Für jedes Level werden ein Musikstück und dessen Wiedergabeverhalten festgelegt: einmalige Wiedergabe oder fortlaufende Wiederholung.

Die beiden derzeit verfügbaren Level, *Level1Ep1* und *MonsterLair-Level1*, verwenden *itcc.mp3* im Loop. Beim Betreten eines neuen Levels beginnt dessen Musik bei Position 0.

=== Kampfmusik und Gegnerkategorien

Gegner erhalten eine Musikkategorie: *Normal, Boss, Superboss oder Final*. Jeder Kategorie kann ein eigenes Kampfmusikstück zugeordnet werden. Bei mehreren Gegnern bestimmt die höchste Kategorie das Musikstück.

Aktuell verwenden alle Kategorien vorläufig *boss_battle.mp3*. Kampfmusik läuft im Loop. Wird dasselbe Stück weiterhin benötigt, startet es bei einem Kategorie- oder Lautstärkewechsel nicht erneut.

Beim Kampfbeginn wird die Levelmusik ausgeblendet und an ihrer aktuellen Abspielposition pausiert. Die Kampfmusik wird eingeblendet.

Sind sämtliche betreffenden Gegner tot, besiegt oder erfolgreich geflüchtet, setzt die Levelmusik an ihrer unterbrochenen Position fort.

=== Musik nach eigener Flucht

Die Flucht der Party beendet die Kampfmusik nicht, solange ein beteiligter Gegner als Bedrohung im Level verbleibt. Ohne aktiven Kampf läuft sie leiser weiter; die Levelmusik bleibt pausiert.

Verlässt die Party das Level, endet die bisherige Kampfmusik und die Musik des neuen Levels übernimmt.

Musikwechsel erfolgen mit einer kurzen Überblendung, derzeit *0,35 Sekunden*. Die vorläufigen Lautstärken betragen *−6 dB* für Levelmusik und aktive Kampfmusik sowie *−14 dB* für weiterlaufende Kampfmusik nach eigener Flucht.

Abspielpositionen und verbleibende Musikbedrohungen werden derzeit nicht im Spielstand gespeichert.

=== Weitere Entwicklung und Balanceprüfung

Trefferzonen, örtlicher Schutz und richtungsabhängige Abwehr sind als erste Ausbaustufe integriert. Weitere Schwachpunktmechaniken, Angriffsflächen und taktische Bewegung bleiben geplant.

Eine feste Zielvorgabe für die Kampflänge ist noch nicht beschlossen. Stärkevorräte und Angriffswerte werden deshalb vorerst nicht auf eine bestimmte Trefferzahl abgestimmt.

Weitere taktische Angriffsarten sollen über Fähigkeiten und Fertigkeiten gestaltet werden. Dafür werden derzeit noch keine neuen Mechaniken festgelegt.

Die textuelle Kampfsimulation im Hauptmenü dient zur Prüfung der aktuellen Regeln. Sie erlaubt einstellbare Charaktere, einzelne Kampfschritte und Serienvergleiche. Die Simulation nutzt die allgemeinen Zonen-/Schutzregeln mit Standardzonen; sie simuliert keine räumliche Aufstellung oder taktische Trefferstellenwahl.