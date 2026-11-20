
#import "@preview/ilm:3.0.0": *

#set text(lang: "de")

#show: ilm.with(
  title: [#align(center)[#image("res/NE-Cota-Logo.png", width: 100%)] Design-Dokument],
  authors: "Peter Sebastian Hansel",
  abstract: [Version: 5

Abgleich mit dem aktuellen Code: 19. November 2026.

(Wird bei jeder Bearbeitung inkrementiert)
],
)

#cover-page()

#outline()

#set document(title: "NE — Call of the Abyss: Design-Dokument", author: "Peter Sebastian Hansel", date: datetime(year: 2026, month: 11, day: 18))
#set text(lang: "de", size: 10pt)
#set page(margin: (x: 2cm, y: 2.2cm))
#show heading.where(level: 1): it => pagebreak(weak: true) + it

#include "/inhalt/statusundgeltung.typ"
#include "/inhalt/basicpitch.typ"
#include "inhalt/tg.typ"
#include "inhalt/interaktionsbasics.typ"
#include "inhalt/rpgmechaniken.typ"
#include "inhalt/spielablauf.typ"
#include "inhalt/spielefenster.typ"



= Aktueller Umsetzungsstand

Dieser Abschnitt beschreibt den Code vom 30. Oktober 2026 einschließlich der
laufenden lokalen Änderungen. Bei Abweichungen bleibt das vorstehende Zielbild
als *Planung* erhalten; es wird nicht als bereits verfügbare Funktion ausgegeben.

== Überblick
#table(
  columns: 3,
  table.header([Bereich], [Status], [Tatsächlich vorhanden / Grenze]),
  [Spielwelt], [Umgesetzt], [3D-Physik mit 2.5D-Darstellung, zwei Prototyplevel; keine vollständige Kampagne],
  [Charakterdaten], [Teilweise umgesetzt], [gemeinsame Resources/IDs, Attribute, Talente; Merkmalsmodifikatoren und reguläre Charaktererschaffung fehlen],
  [Entwicklung], [Teilweise umgesetzt], [XP-Methoden/Training vorhanden; kein vollständiger Lehrer-/Aktions-XP-Ablauf ],
  [Party], [Teilweise umgesetzt], [ - Dannerman und Shalka können beide führen; 
  - Rekrutierung/Formation fehlen],
  [Interaktion], [Teilweise umgesetzt], [Radius, Aktionen und Hervorhebung; kein allgemeines Wahrnehmungs-/Materialsystem],
  [Dialog/Wissen], [Teilweise umgesetzt], [ Dialogue Manager, eigene UI und figurenspezifisches Wissen; kein allgemeines Ermittlungsframework],
  [Inventar/Handel/Diebstahl], [Umgesetzt mit Grenzen], [geprüfte Transfers und Händlerbestände; kein allgemeiner Rückkauf],
  [Kampf], [Teilweise umgesetzt], [Initiative, Gegenstände, Schaden, Bewegung, reale Fluchtwege; Trefferzonen und örtlicher Schutz integriert; Statussystem und Recovery fehlen],
  [Quest], [Teilweise umgesetzt], [geprüfter Banditenablauf; keine universelle Questzustandsmaschine],
  [Speichern/Laden], [Teilweise umgesetzt], [manuelle Saves, Validierung/Migration, Weltaufbau; bekannte Fehler im Levelwechseltest],
  [Spielefenster/Karte], [Umgesetzt mit Grenzen], [ Cover Flow, Inventare, Kartenerkundung; Karte ohne Sichtprüfung/Stockwerkstrennung],
  [Grafik/Musik], [Umgesetzt], [Qualitätsstufen, 3D-Auflösung, Level-/Kampfmusik; FPS-Gewinn einfacher Stufe nicht gemessen],
  [Sequence-System], [Teilweise umgesetzt], [MVP mit wait/set/end/abort; weitergehende Regie und Resume geplant],
  [JSON-Charakterregeln], [Geplant], [32 Entwurfsdateien vorhanden; kein Importer, keine Spielwirkung],
  [Releaseplattformen], [Geplant], [Exportpresets sind kein Nachweis veröffentlichter oder abgenommener Builds],
)



== Architektur und gemeinsame Weltregeln

*Umgesetzt.* `MainGame` ist der Spielanker. Systeme leben unter
`MainGame/Systems`, Level unter `World/LevelRoot`, die Party unter
`World/EntityRoot`. `src/core`, `gameplay`, `world`, `resources`, `ui` und `debug`
bleiben die vorhandenen Zuständigkeitsbereiche. Der Projektname begründet keine
2D-Physikarchitektur. `project.godot` verwendet Godot 4.7 / Forward+; die zuletzt
verwendete vollständige Installation ist Godot 4.7.2 Mono. Dialogue Manager
3.10.5, Terrain3D und das projekteigene Sequence-Exportplugin sind aktiviert.

`GameState.world_state` ist der autoritative Sitzungszustand ohne Node-Referenzen:
Charaktere, Flags, Orte, Objekte, Platzierungen, Party, Händler, Quests,
Kartenerkundung, Wissen und Ereignisse. `CharacterRegistry` verbindet stabile
Character-IDs mit Vorlagen und Laufzeitdaten. Actor-Nodes verkörpern diese Daten;
sie bilden keine zweite unabhängige Charakterbuchhaltung. Inventarbesitz liegt
in `CharacterResource.inventory`. Entfernte eindeutige Weltobjekte bleiben entfernt.

`GameState.meets_condition`, `apply_effects` und `apply_effects_if` verwenden
`WorldRules`. Unbekannte Operationen und ungültige Parameter werden abgelehnt.
Effektfolgen prüfen Arbeitskopien und übernehmen Wissen, Flags, Gold, Beziehungen,
Inventare, Händlerbestand und Ereignisse erst nach erfolgreicher Gesamtprüfung.
Direkte Legacy-Schreibzugriffe sind nicht automatisch Teil dieses Vertrags.


#table(
  columns: 2,
  table.header([Umgesetzte Bedingungen], [Umgesetzte Effekte]),
  [`flag_equals`, `knows_fact` ], [`set_flag`, `learn_fact`, `forget_fact`],
  [`relationship_at_least`, `has_item`], [`change_relationship`, `change_gold`],
  [`relationship_at_least`, `has_item`], [`change_relationship`, `change_gold`],
  [`quest_state` für Banditenquest, `event_occurred`], [`start_quest`, `complete_quest`],
  [],[`transfer_item`, `remove_item`, `steal_item`, `shop_buy`, `shop_sell`],
)



Wissen gehört einer bestimmten Figur; Registryexistenz bedeutet keine aktive
Partymitgliedschaft. Persistente Weltereignisse besitzen fortlaufende IDs, Typ
und Nutzdaten, aber keine Simulationsuhr. Niederlage, Questabschluss, Transfer,
Diebstahl, Entfernung, Kauf und Verkauf sind angeschlossen. Laden spielt sie
nicht erneut ab. Das sichtbare `EventLog` ist davon getrennt.

*Verbindliche Architektur:* vorhandene Systeme erweitern; keine parallelen
Charakter-, Kampf-, Dialog- oder Speichersysteme einführen. Eingabesperren haben
Besitzer: `acquire_input_lease(owner)` liefert einen Token, nur der eigene Token
wird mit `release_input_lease(token)` freigegeben. Legacy-Lock-Zähler existieren
daneben. Abbruch, Fehler und Szenenabbau bereinigen eigene Handles/Signals/Zustände.

== Charakterregeln: Ist-Stand und Abweichungen vom Ziel

*Teilweise umgesetzt.* `CharacterResource` enthält ID/Name, Ausbildung,
Spezies, Herkunft, Ziel, Besonderheiten, sieben Basisattribute, Talente/XP,
Training, aktuelle Punkte, Fraktionen/Beziehungen, Gold, Inventar und Niederlagestatus.
Persönliches Ziel ist Text ohne unmittelbaren mechanischen Effekt.

Auswahlwerte existieren für Ausbildung (keine/Krieger/Gelehrter/Handwerker),
Spezies (keine/Mensch/Elf/Zwerg), Herkunft (keine/Waise/adelig/bürgerlich) und
Besonderheiten (keine/mutig/feinfühlig/geduldig). Sie erzeugen noch keine
automatischen Boni, Mali, Talentpakete oder Caps. Die Konstante „zwei
Besonderheiten“ wird nicht allgemein als Aufnahmegrenze durchgesetzt.

```text
| Regel | Umgesetzt | Geplant bzw. offen |
| Attribute | `max(0, Basis + Summe zugeordneter Talentstufen)`; Vorlagen haben Basiswerte | Wertebildung aus Merkmalen, Umstands-/Statusmodifikatoren |
| SP-Basis | Körperkraft + Gewandheit + 2 × Robustheit | schnelle Regeneration und besondere Heilung negativer Verletzungen |
| KP-Basis | Verstand + Willenskraft + 2 × Bewusstsein | regulärer KP-Verbrauch bis zur negativen Basis |
| Tod | aktuelle SP ≤ negative SP-Basis; 0 SP ist keine automatische Bewusstlosigkeit | Wiederbelebung, Recovery, endgültige Folgen |
| Kosten/Heilung | positive KP-Kosten brauchen ausreichenden Vorrat; Heilung/KP-Wiederherstellung ohne Basisobergrenze | Heilungslimit, Regeneration, Erschöpfungsregeln |
| Talentstufe | 100 XP je Stufe, +1 auf zugehöriges Attribut | automatisches Lernen durch Handlungen/Lehrer |
| Talentcap | Standard 10 + `skill_level_cap_bonus` | Designziel 20 mit Merkmalsabhängigkeit |
| Training | höchstens fünf aktive Talente; Aktions-XP nur für markierte Talente | vollständiger regulärer Lernablauf; Kampf vergibt nicht automatisch Aktions-XP |
| Talentplätze | fünf sichtbare Plätze je Attribut | einheitliche Durchsetzung durch alle Lernmethoden |
| Tragkraft | `10 + 5 × effektive Körperkraft`; Gewicht aus Rucksack und Ausrüstung | 0–10-Gewichtsmodell, Händetragen und Überlastfolgen |
```


Beim Talentaufstieg erhöhen sich positive aktuelle SP/KP jeweils um 1 bis zur
neuen Basis; 0/negative Werte werden nicht aufgefüllt. Der freie XP-Pfad ist
noch keine verlässliche fertige Spielerregel: Er verwendet zurückgegebene
Rest-XP als Wahrheitswert und kann den freien Vorrat falsch abbuchen.

*Aktuelle Vorlagen:* Dannerman hat Basisattribute 3/2/2/2/2/2/3, Shalka
2/3/2/2/2/3/2 (Körperkraft, Gewandheit, Robustheit, Willenskraft, Verstand,
Bewusstsein, Präsenz). Talentboni ergeben SP/KP/Tragkraft 12/10/40 bzw. 11/12/20.
Dannerman startet mit 50 Gold, 50 freien XP und seinem bisherigen Messer im
Rucksack, Shalka mit 20 Gold. Beide erhalten zusätzlich je einen Bogen, Speer,
Dolch, ein Schwert und 20 Pfeile im Rucksack. Die Gegenstände sind zunächst
nicht ausgerüstet. Diese Startausstattung gilt für neue Spielsitzungen; beim
Laden bleibt der gespeicherte Besitz erhalten. Die ausgerüsteten Gegenstände werden an den Handknochen dargestellt.
Spielstände können abweichen. Portrait/Paperdoll verwenden
`assets/characters/<name>/<name>_portrait.png` bzw. `<name>_paperdoll.png`.

Beziehungen sind gerichtet, auf −10 bis +10 begrenzt. Persönliche Einträge gehen
Fraktionswerten vor; unter passenden Fraktionswerten gewinnt der größte absolute
Betrag. Soziale Talente allein sind keine allgemeine Überredenprobe. Befristete
Begleiterverträge, Bedürfnisse/Ängste, Gerüchte, Tagesabläufe, zeitabhängige
Anwesenheit und ein vollständiges Buch der Charaktere sind noch nicht umgesetzt.

== Steuerung, Interaktionen und Transaktionen

*Teilweise umgesetzt.* WASD, Shift-Sprint, Leertaste-Sprung, Linksklick bzw.
gehaltener Linksklick zur Mausbewegung, E/Rechtsklick für Interaktion, I/C für
Inventar/Charakter und F für Partyfähigkeiten sind vorhanden. Standard-UI-Fokus,
Bestätigung/Abbruch und Fensterwechsel per Q/E bzw. Schultertasten existieren.
Vollständige Bedienbarkeit sämtlicher Abläufe allein mit Controller oder
Pfeiltasten wird damit nicht als abgeschlossen behauptet.

3D-Bewegung nutzt Kollision, Gravitation, Sprung und Stufenhilfe. `StateWalk`
verwendet Gehen 1,5, Sprint 3,75, Beschleunigung 6 und Abbremsen 9.
Begleiter folgen direkt dem Leader, keiner allgemeinen Formationskette.

Das Aktionsmenü sucht `interactable`-Nodes im horizontalen Radius 1,5 um den
Leader, zeigt deren verfügbare Aktionen, Radius und temporäre Hervorhebung.
Es stoppt den handelnden Charakter, aber nicht allgemein Welt und Animationen.
Wahrnehmungsabhängige Radien, Hinweise weiterer Partymitglieder, unbekannte
Namen mit „???“, Grauschleier/Freeze, frei wählbare Highlightstile und ein
allgemeiner Materialsimulator bleiben Ziele des vorstehenden Interaktionsdesigns.

Konkrete Abläufe existieren für Aufnahme/Verwendung, NPC-Gespräch, Handel,
Übergabe, Diebstahl, Angriff und Pflanzen schneiden mit bereitgehaltenem Messer.
Händetragen, NPCs tragen, Ablagezug im Kampf und allgemeine Brennen-/Asche-/
Wasserreaktionen sind nicht aus diesen Einzelbeispielen abzuleiten.

*Diebstahl umgesetzt:* `clamp(0,5 + 0,04 × (Gewandheit Dieb − Bewusstsein Opfer),
0,05, 0,9)`. Erfolg überträgt ein Rucksackstück; Ausrüstung gehört nicht zum
Angebot. Vorprüfungsfehler wie fehlender Bestand/Übergewicht sind keine
Entdeckungswürfe. Ein misslungener Wurf startet Kampf mit dem Opfer als Angreifer.
Die geplante Voraussetzung Stehlen ≥ 1 ist nicht mit dieser vorhandenen Formel
gleichzusetzen.

*Handel umgesetzt:* Ein Klick bewegt eine Einheit. Gold, Bestand, Inventar,
Besitzer und Traglast werden gemeinsam geprüft. Bestand −1 ist unbegrenzt.
Verkäufe füllen das Angebot nicht auf. Nicht gelistete Typen verwenden den
Ersatzpreis `max(1, int(weight × 10))`; Rückkauf ist keine fertige Regel.

== Party, Inventare und Fenster

*Umgesetzt mit Grenzen.* `GameWindows` unter `UI/MenuRoot` zeigt die sieben
zyklischen Seiten in der beschriebenen Reihenfolge. Seitenkarten tragen Titel,
keine eigenen Live-Renderings. Mitte und eingebettete CharacterSheetUI-/InventoryUI-/
MapUI-Inhalte werden gemeinsam verwaltet; Seitenwechsel räumen Views/Signale auf.
Die Fenster sperren Weltsteuerung mit einer eigenen Lease, pausieren aber nicht
die Simulation. Speichern/Laden und Debug übernehmen nach Schließen ihre Sperre.

Dannerman und Shalka können beide Anführer werden. Platz 1 bestimmt Leader,
Follower, Kamera, HUD und gespeicherte Reihenfolge, ohne Nodes zu ersetzen.
Kampf, Pause, fremde Sperren und tote Leaderkandidaten verhindern Wechsel.
Gespeichert sind `leader_id` und geordnete `member_ids`. Rekrutierung/Entlassung
und Formation fehlen. Die scrollbare UI hat keine allgemeine feste Mitgliederzahl;
der aktuelle Speichervertrag akzeptiert jedoch nur Dannerman/Shalka.

Inventarplätze sind Kopf, Rumpf, rechte Hand (`primaer_hand`), linke Hand
(`nebenhand`), Beine, Füße, Schmuck und neun `guertel_*`-Schnellplätze.
Es gibt keinen zusätzlichen Waffenplatz. Körperplätze prüfen Itemzuordnung und
schließen Verbrauchsgegenstände aus; Hände/Schnellplätze nehmen beliebige Items
auf. Je Platz ein Exemplar, Rucksackstapel gemäß jeweiliger Stapelgrenze.

Aktionsmenü und Drag-and-drop ermöglichen Ausrüsten, Tauschen, Verstauen,
Verwenden, Ablegen und Übergaben zwischen Partyrucksäcken. Übergabe bewegt ein
Stück mit Besitzer-/Traglastprüfung. Verdrängte Items werden nötigenfalls verstaut.
Eigenschaften ausgerüsteter Items sind ohne Ablegen sichtbar. „Weitere Infos“
bleibt leer. Weltpanels zeigen Portrait/SP/KP und weichen bei Überlappung aus.

*Karte umgesetzt:* vereinfachte X/Z-Meshumrisse, Zoom/Ziehen/Übersicht.
Alle 0,2 Sekunden werden Zellen von 2 Welteinheiten im Radius 8 um den Leader
entdeckt, auch bei geschlossener Karte. Wände blockieren das nicht. NPC-/
Objektmarkierungen behalten außerhalb des Radius die letzte bekannte Position;
entfernte Weltobjekte verschwinden. Stockwerke werden übereinander projiziert;
Terrain3D, CSG und Spritegeometrie werden nicht kartografiert. Statische
Geometrie wird beim Levelaufbau erfasst.

*Log/Optionen umgesetzt:* `EventLog` hält bis zu 100 sichtbare Textzeilen für
neu geöffnete Ansichten. Kampf, Dialog und Aufnahme sind angeschlossen; dies
ersetzt keine persistente Ereignishistorie. Lautstärke je Audiobus gilt für die
Sitzung. Grafikpräferenzen sind lokal persistent; eine allgemeine persistente
Sprach-/Audio-/Steuerungsverwaltung ist offen.

== Kampfablauf ergänzend zu den Schadensregeln

*Umgesetzt.* CombatManager/CombatSession führen einen zentralen Kampf in der
normalen 3D-Welt. Ein Angriff prüft reaktionsfähige Figuren im Radius 8 um den
Angreifer. Späteres Heranlaufen allein ist keine allgemeine laufende Rekrutierung.
Positive Beziehung zum Opfer unterstützt es bei mindestens gleich hoher Sympathie
wie zum Angreifer; sonst gewinnt höhere positive Sympathie zum Angreifer.
Partyzugehörigkeit ist Auffangregel ohne eindeutige soziale Zuordnung.
Negative Beziehungen allein erzwingen keinen Beitritt. Partyfiguren können
aufgrund der Beziehungen auf unterschiedlichen Seiten landen.

Initiative startet bei 0, wächst um `effektive Gewandheit × 6` pro Sekunde und
reiht bei 100 einen Zug ein, wobei 100 abgezogen werden. Aktive und bereits
wartende Figuren sammeln nicht weiter; andere auch während der Menüwahl.
Ein aktiver Zug, Gleichstände nach Teilnehmerreihenfolge; Gewandheit 0 sammelt
nichts. Ein Rundensignal ist keine angeschlossene Regeneration/Statusdauer.
Alle Partyfiguren werden im eigenen Zug manuell bedient, echte NPCs automatisch.

=== Charakterkarten und Zugreihenfolge im Kampf

*Implementiert:* Die bisherige Initiative-Balkenanzeige ist durch eine
horizontale Reihe der vorhandenen Charakterkarten am oberen Bildschirmrand
ersetzt. Außerhalb des Kampfes bleiben die Partykarten über den Köpfen.
Beim Kampfstart werden dieselben Panel-/Karteninstanzen übernommen und in
0,3 Sekunden an den oberen Rand bewegt. Karten einschließlich Portrait,
Schrift, SP-/KP-Balken und Abständen skalieren auf 50 Prozent. Zusätzliche
Kombattanten erhalten dieselbe Kartenansicht und blenden sich von oben ein.
Bei Platzmangel verkleinert sich die gesamte Reihe zusätzlich gleichmäßig,
sodass kein Kombattant abgeschnitten wird. Die Karten blockieren keine Eingaben.

Links steht der aktive Kombattant, danach die vorhandene Zugwarteschlange.
Der Rest wird anhand der erwarteten Zeit bis zur Initiative-Schwelle sortiert:
`max(0, 100 − Initiative) / (effektive Gewandheit × 6)`. Gewandheit 0 steht
hinten; Gleichstände bleiben in Teilnehmerreihenfolge stabil. Pro Kombattant
erscheint eine Karte. Diese Vorschau berücksichtigt laufende Attributänderungen;
sie ist für noch nicht eingereihte Züge eine Prognose. Nach einem Zug wird die
Karte entsprechend ihrer nächsten Bereitschaft neu einsortiert. Sehr schnelle
Figuren können deshalb vor anderen erneut drankommen. Umsortieren wird kurz
animiert; es werden keine Karten pro Frame neu erzeugt.

Flucht und KO entfernen die Karte sofort aus der sichtbaren Sortierung. Sie
wird ausgegraut, nach oben geschoben und ausgeblendet, anschließend werden
Karten-Node und UI-Referenzen freigegeben. Der autoritative CombatParticipant
bleibt für Kampfabschluss und mögliche Rückkehr erhalten; die UI löscht keine
Charakterdaten. Bei Rückkehr während der Ausblendung wird diese abgebrochen;
nach bereits abgeschlossener Entfernung entsteht genau eine neue Karte.
`CombatSession.admit()` unterstützt nachträgliche Teilnehmer und meldet auch
zurückkehrende Geflohene über `participant_joined`. Eine noch laufende
Fluchtbewegung wird bei erneuter Aufnahme beendet.

Am Kampfende bewegen sich überlebende Partykarten in Originalgröße zurück über
die Köpfe. Ausgeschiedene Partymitglieder erhalten außerhalb des Kampfes wieder
eine Weltkarte; Gegnerkarten verschwinden. Menü-Partyansichten bleiben separat.
Session-Signale, Tweens und ausgeliehene Panels werden auch beim HUD-/Szenenabbau
bereinigt. Die Darstellung ist kein gespeicherter Kampfzustand.

`test_combat_cards.tscn` prüft Kartenidentität, Skalierung, Zugfolge,
Geschwindigkeitsänderungen, KO/Flucht, Beitritt, Rückkehr und Freigabe.
Mit `-- --preview-cards` bleibt die Anfangsaufstellung für eine visuelle Prüfung
kurz geöffnet. Animationszeiten und Skalierung stehen in `NEDimensions`.

Aktionen: Schlag bei freier Hand, Gegenstand, Fähigkeit, Bewegung, Reden, Flucht.
Ausgelöste Aktionen können auch bei Fehlschlag den Zug verbrauchen;
Zurücknavigation nicht. Nur Hände/Schnellplätze liefern Kampfgegenstände.
Zwei belegte Hände erzeugen keinen Doppelangriff. Kampfbewegung erfolgt über
Rasterfelder; außerhalb des Kampfes bleibt freie Bewegung erhalten.

*Kampfraster (implementiert):*

- Quadratische Zellen von 1 × 1 m, weltweit an ganzzahligen X-/Z-Meterpositionen
  ausgerichtete Zellmitten. Kein Szenenwechsel und keine Umstellung auf 2D-Physik.
- Bei Eintritt und Rückkehr nach Flucht werden Figuren auf nahe freie, begehbare
  Zellmitten eingeordnet. Die Suche reicht bis vier Zellen je Achse; eine
  Körperprüfung verhindert Einordnung durch Wände. Ohne geeigneten Platz bleibt
  die Figur stehen und erhält einen Hinweis; Rasterbewegung ist dort nicht möglich.
- Eine dezente Rasteranzeige erscheint lokal um die aktiven Kampfteilnehmer und
  verschwindet bei Kampfende. In „Bewegen“ werden erreichbare Felder zurückhaltend
  grün gezeichnet; das ausgewählte Feld ist eine deutlich hellere goldene Fläche
  mit vollem Rand.
- Zielfeld per Linksklick auf den Boden oder WASD/Bewegungstasten wählen.
  Die Auswahl zeigt tatsächliche Wegkosten und das Bewegungsbudget
  `max(1, effektive Gewandheit) × 1 m` an.
- Gemeinsame Dijkstra-Wegsuche für Spieler und KI mit acht Bewegungsrichtungen.
  Gerade Schritte kosten 1 m, diagonale etwa 1,41 m; Höhenunterschiede zählen
  zur Weglänge. Wände, Figuren, belegte Felder und nicht begehbarer Boden sperren
  Wege. Diagonales Abschneiden blockierter Ecken ist ausgeschlossen.
- Erst „Bewegung ausführen“ startet den physischen Weg mit 1 m/s. Abbrechen vor
  dem Start verändert keine Position und verbraucht keinen Zug. Nach dem Start
  kostet auch eine blockierte Bewegung den Zug; sie kann nicht zurückgenommen werden.
- Die Kampfkamera wird beim Eintritt in die Feldwahl in ihrer aktuellen Pose
  gehalten. Sie bleibt sowohl während der Auswahl als auch während des physischen
  Bewegungswegs still und wird beim Verlassen des Bewegungszugs wieder freigegeben.
  Ein besitzergebundener Handle verhindert, dass ein anderer Kameraablauf diese
  Pause versehentlich aufhebt.
- Zielbelegung und Weg werden beim Start erneut geprüft. Die bestehende
  Körperphysik und Blockierungserkennung führen den Weg aus; erfolgreiche Bewegung
  endet auf einer Zellmitte. MOVE bestätigt die erreichte Position, ohne zu teleportieren.
- Reichweiten bleiben räumliche Meterabstände zwischen Standpositionen, mit 1 mm
  numerischer Ankunftstoleranz. Ein Dolch mit 1 m Reichweite erreicht ein gerades
  Nachbarfeld, aber kein diagonales. Bestehende Waffenwerte bleiben passend erhalten.
- Angriffslinien, Abfänger, Trefferzonen, Blickrichtung und Richtungsrüstung bleiben
  räumlich wirksam. Das Raster ersetzt keine Trefferermittlung.
- Freie Erkundungsbewegung und die laufende Flucht zu Fluchtbereichen verwenden
  weiterhin ihre bisherigen Bewegungsregeln. Es werden keine Rasterdaten gespeichert.
- Grenzen: vor allem ebene Böden/kleine Stufen; mehrzellige große Lebewesen sind
  noch nicht implementiert. Die Wegsuche ist technisch auf höchstens 35 m Budget
  pro Berechnung begrenzt; die KI sucht standardmäßig bis 6 m.
- Prüfung: `test_combat_grid.tscn` besteht mit 41 Prüfungen sowohl headless als
  auch gerendert unter Godot 4.7.2. Enthalten sind Eintritt/Rückkehr, Feldbelegung,
  Wegkosten, blockierte Ecken, Dolchreichweite, KI, Maus-/Tastaturauswahl, Abbrechen,
  neue Teilnehmer/Hindernisse, Kamerahalt während Auswahl und Bewegung sowie freie
  Positionen nach Kampfende. Rasteranzeige und Menü wurden anhand einer gerenderten
  Vorschau kontrolliert.
- Bestehende Tests bestehen ebenfalls: NPC-KI (36), Taktik (18), Waffenreichweiten
  (46), Blickrichtung (12), Flucht (78), Kampfquest (31) und Kampfkarten (25).
  Für Flucht/Kampfquest wurden nur temporäre Testkopien mit `user://` anstelle
  der vorhandenen `/tmp/`-Speicherpfade verwendet.

Sichtprüfung blockiert passende Fähigkeiten durch Wände oder andere Körper. Waffenangriffe treffen stattdessen den ersten aktiven Kampfteilnehmer auf ihrer Angriffslinie; Wände blockieren weiterhin.
Waffenverwendungen und Nahkampffähigkeiten prüfen ihre numerische Reichweite.
Separate Regeln für weitergehende Magiedistanzen sind noch offen.
Reden ruft NPC-Interaktion auf; Überzeugen/Kapitulation/Friedensschluss brauchen
konkrete Regeln. Die NPC-KI nutzt den unten beschriebenen LimboAI-Zugablauf.
Automatische Flucht, Heilung und Fähigkeitskombinationen sind noch offen.

=== KI-Werkzeuge und implementierter Nahkampf-Prototyp

*Installiert:* LimboAI *1.8.1* als GDExtension unter `addons/limboai/`.
Quelle: #link("https://github.com/limbonaut/limboai/releases/tag/v1.8.1")[offizieller Release v1.8.1],
Archiv `limboai+v1.8.1.gdextension-4.6.zip`.
Veröffentlichte und vor Installation geprüfte SHA-256:
`0910411f8dbc0da8920f6c8bbbb6397c347cd9f2f193942468a702dfb11d5f0e`.
Die unveränderten Addon-Dateien einschließlich Plattformbibliotheken und
MIT-Lizenz sind enthalten; das Demo-Projekt wurde nicht übernommen.
Es ist keine neue Godot-Version und kein eigener Engine-Build erforderlich.

Die native Erweiterung wird über `addons/limboai/bin/limboai.gdextension`
beim Projektimport erkannt; sie besitzt keine `plugin.cfg` und benötigt
keinen zusätzlichen Eintrag in `[editor_plugins]`. Nach Installation muss
Godot das Projekt neu laden, damit die nativen Klassen und der Editor verfügbar
sind. `NavigationAgent3D` gehört bereits zur Engine. Beehave ist eine alternative
Verhaltensbaum-Lösung und wurde nicht zusätzlich installiert.

`test_ai_extensions.tscn` lädt die Erweiterung bei Bedarf ausdrücklich und
prüft ihre Klassen, Blackboard sowie die Ausführung einer einfachen nativen
BehaviorTree-Aufgabe unter der vorhandenen Godot-4.7.2-Version.
Andere Exportplattformen sind durch Paketdateien vertreten, aber nicht getestet;
es werden nur die von upstream tatsächlich mitgelieferten Plattformen unterstützt.

*Implementiert:* `NPCCombatBrain` startet pro aktivem KI-Zug einen eigenen
LimboAI-Runner unter der vorhandenen CombatSession. Der Verhaltensbaum
`src/resources/combat/ai/melee_tree.tres` plant eine Handlung und führt sie aus.
Die Projektaufgaben und die Bewertung liegen getrennt unter
`src/gameplay/combat/ai/`; Drittanbieter-Code bleibt unverändert.

Jeder NPC besitzt im Inspector `combat_ai_profile`; Standard ist
`src/resources/combat/ai/melee_default.tres`. Für andere Gegner dieses Profil
duplizieren und z.B. Wahrnehmungsradius (Standard 8 m), bevorzugten Abstand
(80 % der verfügbaren Waffenreichweite), Schadens-/Beziehungs-/Verwundungsgewichte
oder Suchbudget verändern. Das Profil verweist auf den austauschbaren
Verhaltensbaum. Es gehört zur Szenenkonfiguration; CharacterRegistry und
Save-Schema erhalten keine laufenden KI-Zustände oder duplizierten Charakterdaten.

Die KI berücksichtigt bis zu drei nahe sichtbare Gegner der gegnerischen
Kampfseite. Sie prüft ausgerüstete Waffen und Schnellplätze, fehlende Munition,
Reichweite, Körperzonen und Panzerung. Eine freie Hand erlaubt Fausthieb.
Angriffe nutzen dieselbe räumliche Trefferermittlung wie der Resolver;
freundliche und neutrale Abfänger werden verworfen. Unmittelbar vor der
Ausführung werden Ziel, Ausrüstung und Angriffslinie erneut geprüft.

*Ergänzung – notwendige KI-Bewegung und Verfolgung (implementiert):*

- Ohne gültigen Angriff sucht die KI eine freie Angriffslinie innerhalb der
  Waffenreichweite. Ist das in einem Zug möglich, verwendet sie erreichbare
  Rasterfelder wie bisher; Verbündete werden dabei nicht absichtlich beschossen.
- Liegt eine geeignete Angriffsposition weiter entfernt, plant sie einen Weg über
  mehrere Züge. Dafür dient `approach_planning_distance` im Gegnerprofil
  (Standard 12 m Weglänge). Ein nötiger Umweg darf zunächst vom Gegner wegführen,
  statt nur den Luftlinienabstand zu verkleinern.
- Die Vorausschau verwendet dieselben Boden-, Körper-, Wand- und Eckprüfungen
  wie Spielerbewegung. Sie bevorzugt die kürzeste erreichbare Route zu einer
  tatsächlichen Angriffsmöglichkeit; bei gleich langen Routen zählt die
  Angriffsbewertung. Einzelschritte müssen in einen eigenen Bewegungszug passen:
  mit nur 1 m Budget werden keine diagonalen Schritte von etwa 1,41 m eingeplant.
- Aus dem längeren Weg wird nur der Teil innerhalb des normalen eigenen
  Bewegungsbudgets und `movement_search_radius` ausgeführt. Die Vorausschau
  gewährt keine zusätzliche Bewegung und keinen Angriff im selben Zug.
- Sichtbare Gegner werden am Beginn eines eigenen KI-Zugs mit ihrer tatsächlich
  gesehenen Position gemerkt. Nach Sichtverlust kann die KI dorthin weiterlaufen,
  ohne den unbekannten aktuellen Standort des Gegners für die Zielplanung zu nutzen.
  Andere sichtbare Gegner haben Vorrang vor der Suche nach verdeckten Zielen.
- `target_memory_turns` bestimmt die Erinnerungsdauer (Standard 3 eigene Züge;
  0 schaltet die Verfolgung nach Sichtverlust ab). Erneuter Sichtkontakt aktualisiert
  die Position. Veraltete Einträge, ausgeschiedene Ziele und erfolglos erreichte
  Suchpositionen werden beim nächsten Beobachtungsdurchlauf verworfen.
- Das Gedächtnis liegt ausschließlich im CombatParticipant und enthält Actor-IDs,
  Positionen und Alter. Rückkehr nach eigener Flucht leert es; keine neuen
  Charakter- oder Save-Felder und keine Referenzzyklen zwischen Teilnehmern.
- Ohne gefundenen mehrzügigen Weg bleibt die bisherige lokale Annäherung möglich.
  Ist keine sinnvolle Bewegung erreichbar, gibt die KI ihren Zug sauber frei.
  Bei jedem eigenen Zug und vor dem Bewegungsstart wird neu geprüft.
- `test_npc_navigation.tscn`: 55 Prüfungen bestanden, einschließlich einer
  mehrzügigen Sackgassenumgehung bis zum tatsächlichen Angriff, ohne Pendeln,
  mit nur 1 m Zugbudget; außerdem Sichtverlust, kein Standortwissen über verdeckte
  Gegner, Verfall/Abschaltung des Gedächtnisses, physische Verfolgung, erneuter
  Sichtkontakt, Flucht/Rückkehr und vollständig blockierte Wege.
- Grenze: begrenzte lokale Vorausschau statt weltweiter Navigation. Eine Route
  außerhalb der eingestellten Planungslänge wird nicht vollständig vorausberechnet.
  Vorhergesagte gegnerische Bewegungen, automatisches Heilen/Fliehen und eigene
  Fernkämpfer-Abstandstaktiken bleiben offen.

*Ergänzung – taktische Positionswahl (implementiert):*

- Die KI kann einen verfügbaren Frontalangriff zugunsten einer deutlich besseren
  Flanken- oder Rückenposition aufgeben. Bewertet werden die vorhandenen
  Trefferzonen, richtungsabhängige Rüstung und freie Angriffslinien.
- Der Positionsgewinn muss den aufgegebenen Angriffszug und den Wegaufwand
  aufwiegen. Standardbedingung nach Prüfung des tatsächlichen Weges:
  `zukünftige Bewertung − 0,5 × Weglänge > 2 × aktuelle Angriffsbewertung + 3`.
- Ein voraussichtlich ausschaltender Treffer hat Vorrang vor dem Positionswechsel.
  Maßgeblich bleibt die bestehende SP-Regel:
  `Schaden >= aktuelle SP + SP-Basis`; 0 SP allein bedeutet kein Ausscheiden.
- Die Schadensschätzung verwendet dieselben Zonen-, Robustheits-, Schutz- und
  Mindestschadensregeln wie der Resolver. Ausweichen wird erst bei der tatsächlichen
  Angriffsausführung gewürfelt.
- Pro Gegnerprofil einstellbar: `tactical_reposition_enabled` (Standard aktiv),
  `reposition_attack_multiplier` (2), `reposition_min_gain` (3),
  `reposition_path_cost` (0,5 pro Meter) und `reposition_cooldown_turns` (1).
- Nach Beginn eines taktischen Bewegungsversuchs ist standardmäßig einen eigenen
  Zug lang kein weiterer Positionswechsel anstelle eines verfügbaren Angriffs
  erlaubt. Das verhindert aufeinanderfolgendes Umkreisen, auch nach einer Drehung
  des Gegners. Normale Annäherung ohne gültigen Angriff bleibt möglich.
- Die Abklingzeit liegt ausschließlich im CombatParticipant, wird bei der Planung
  eines tatsächlichen eigenen Zugs heruntergezählt und bei Wiedereintritt nach
  Flucht zurückgesetzt. Keine neuen persistenten Charakterdaten oder Save-Felder.
- Die Bewertung verwendet erreichbare Rasterfelder und deren tatsächliche
  Wegkosten. Auch taktische Umwege müssen das normale Bewegungsbudget einhalten;
  unerreichbare oder zu teure Wege führen zum verfügbaren Angriff zurück.
- Bewegung verbraucht den gesamten Zug; ein Folgeangriff ist frühestens im nächsten
  eigenen Zug möglich und wird dann anhand des aktuellen Weltzustands neu geprüft.
- Grenze der Planung: Gegnerische Drehungen und Gegenangriffe werden nicht als
  vollständige Folgerunde simuliert. Die Häufigkeit der Manöver bleibt im Spieltest
  über die Profilwerte abzustimmen.

Ohne gültigen Angriff bewertet die KI wie bisher bessere Standorte. Für Kampfzüge
berechnet `combat_grid.gd` alle erreichbaren Rasterwege gemeinsam; ein separates
Navmesh ist nicht erforderlich. Das Standardsuchbudget begrenzt die betrachtete
Wegstrecke eines ausgeführten Zugs zusätzlich auf 6 m; die mehrzügige
Annäherungsplanung betrachtet standardmäßig bis 12 m. Das frühere Profilfeld `max_path_candidates` bleibt
aus Kompatibilitätsgründen erhalten und wird bei der Rasterplanung nicht verwendet.
Das bestehende lokale AStar-Wegenetz in `flee_route.gd` bleibt für Flucht erhalten.
Bewegung verbraucht den ganzen Zug; der Angriff folgt frühestens im nächsten eigenen
Zug. Der MOVE-Resolver bestätigt nur die bereits physisch erreichte Zellmitte.

Flucht und KI verwenden denselben Wegfolger mit getrennten Besitzer-Handles.
Blockierung, Zugende, Zielverlust, KO und Szenenabbau brechen eigene Aufträge ab.
Steckenbleiben und ein Wegzeitlimit verhindern dauerhaft gesperrte Züge.
Neue und zurückkehrende Teilnehmer werden über die bestehenden Session-Verträge
im nächsten Planungsdurchlauf berücksichtigt.

*Prüfstand der taktischen Positionswahl:*

- `test_npc_tactics.tscn`: 18 Prüfungen bestanden; abgedeckt sind direkter Angriff
  ohne Vorteil, Flanke trotz gültigem Frontalangriff, Weg-/Angriffskosten, reine
  Planung ohne Mutation, eigener Bewegungszug, Gegnerdrehung und Folgeangriff,
  Abklingzeit, Profilabschaltung, hohe Wegkosten, tatsächliche SP-Ausscheidensgrenze,
  blockierte Wege und Wiedereintritt.
- Bestehende Prüfungen für NPC-KI (36), Richtungsrüstung (32) und Blickrichtung (12)
  ebenfalls bestanden.
- Eine visuelle Prüfung und Abstimmung des Kampfgefühls im Spiel bleibt offen.

`test_npc_combat_ai.tscn` prüft Waffen-/Munitionswahl, Angriffe, physische Bewegung,
Bewegungsradius, freundliche Abfänger, Folgezüge, Sicht-/Wahrnehmungsgrenzen,
Zielverlust, Actor-Abbau und Besitzerwechsel zur Flucht. Zusätzlich prüft die
Szene die Anbindung eines echten registrierten NPCs über CombatManager im
vorhandenen Level und das normale Kampfende. Unter Godot 4.7.2 bestehen alle
36 Prüfungen. Die vorhandenen Tests für Trefferzonen (58), Schadensregeln (17),
Flucht (78), Fluchtbereiche (808), Kampfquest (31), gehaltene Waffen (36) und
LimboAI (11) bestehen ebenfalls; ältere `/tmp/`-Testpfade wurden für die
Windows-Prüfung nur in temporären Testkopien angepasst. Drei bestehende
Prüfungen in Welt-/Partytests erwarten noch das alte Startinventar bzw. genau
einen Party-Kindknoten ohne `OcclusionVisual`; diese Erwartungen bleiben offen.
Frühere Headless-Editorimporte waren durch DLL-/Dateizugriffsfehler bei Terrain3D,
LimboAI und Editor-Plugins blockiert. Beim Abschluss des Kampfrasters am 17.11.2026
besteht der vollständige Editorimport einschließlich Klassenindex und erzeugter
Script-UIDs. Es verbleibt die bekannte Warnung zum verschachtelten Projekt im
FantasyVillage-Assetpaket. Die Rasteransicht wurde gerendert geprüft; eine
vollständige visuelle KI-Prüfung im regulären Level bleibt offen.
Grenzen: Navigation unterstützt weiterhin vor allem ebene Böden, keine komplexen
Höhenwechsel. Eigene Fernkämpfer-Taktiken, automatisches Heilen/Fliehen,
Fähigkeitskombinationen und gemeinsame Gruppenplanung sind noch nicht implementiert.

Genauigkeit kommt vom Attribut der Verwendung bzw. Quelltalent der Fähigkeit.
Ausweichen = `clamp(0,03 × (Ziel-Gewandheit − Genauigkeit), 0, 0,6)`.
Danach mindert Robustheit den Schaden gemäß den oben beschriebenen aktuellen
Mindestschadens-/Rüstungsregeln. Beim Messer ist Genauigkeit Gewandheit, obwohl
Rohstärke Körperkraft verwendet. Feste Schadensmagie behält ihr `power`.

Aktuelle Itemkampfwerte: Messer 6/8 für Stechen/Werfen, Stein 4/5 für Schlagen/
Werfen. Fehlen Verwendungen, wird improvisiert geschlagen. Wurf/Verbrauch
entfernt das gewählte ausgerüstete Exemplar; Projektilbergung fehlt.
Verbrauch wirkt auf ein aktives Ziel derselben Seite ohne eigenen Distanz-/
Sichtcheck. Heiltrank: 25 SP, keine Basisobergrenze; ausgeschiedene Ziele sind
nicht wählbar.

Schlag ist kostenlos; Feuerstoß verlangt Magiekunde 1, kostet 8 KP, Stärke 14.
Schaden/Heilung sind implementierte Effekte, aber im Katalog fehlt eine aktive
Heilfähigkeit. Schlachtruf ist eine Definition für Bardenkunst 1 und 6 KP;
BUFF/DEBUFF/UTILITY melden `effect_not_implemented`. Der vorhandene Pfad kann
Kosten schon vor dieser Ablehnung abziehen. Das ist keine fertige Buff-Regel.
Partyfähigkeiten unterstützen intern Heilung; offensive Fähigkeiten gegen
Fremde können vor regulärer Initiative als Erstschlag Kampf eröffnen.

Fluchtchance = `clamp(0,5 + 0,02 × (eigene Gewandheit − mittlere aktive
Gegner-Gewandheit), 0,1, 0,9)`. Ein Wurf allein genügt nicht: freier Platz im
passenden Fluchtbereich und begehbarer Weg sind nötig. Die Figur läuft tatsächlich
dorthin; kein Teleport. Unterbrechung kann Flucht aufheben. Fliehende/Entkommene
erhalten keine Züge und sind keine regulären Ziele. Ein einzelner Entkommener
bekommt erst nach Sitzungsende freie Steuerung; erneuter Angriff kann ihn aufnehmen.

Positiver Schaden an der Todesgrenze meldet Niederlage; NPC-Interaktion kann sie
persistent markieren. Heilung hebt die Niederlagemarkierung nicht auf.
Die Sitzung endet bei einer leeren aktiven Seite und noch aktiver Gegenseite.
Beidseitiger Ausfall, Party-Game-over/Recovery, allgemeine Beute und Sieg-XP
sind nicht vollständig geregelt. Flucht ist kein NPC-Niederlageereignis.

Die isolierte Textsimulation nutzt Kopien und die vorhandenen Session-/Resolver-
Regeln, verändert weder Registry/Vorlagen/Welt noch globale Zufallsfolge.
Einzelzug, Einzelkampf und Serien mit 1–500 Kämpfen sind reproduzierbar per Seed.
Talentstufen bis 30 dienen Experimenten. Freie Sicht wird vorausgesetzt; keine
Geometrie, Bewegung, Flucht, Heilstrategie oder Denkzeit. Zeitraster 0,05 Sekunden,
Limit 300 Aktionen/600 simulierte Sekunden. Bei Gleichstand ist A zuerst;
Serien beseitigen diesen Vorteil nicht automatisch.

== Dialoge, Wissen und Banditenquest

*Teilweise umgesetzt.* Dialogue Manager bleibt hinter DialogueSystem und der
projekteigenen Gesprächsoberfläche. `player` wird ausdrücklich als Gesprächskontext
übergeben. Themen, Mutationen, Kamera und Log sind angebunden. Texttempo (Langsam/Normal/Schnell/Sofort) und optionaler Sprechton sind lokal einstellbar; auch gewählte Party-Antworten werden eingetickert. `CharacterResource.voice` steuert die Tonhöhe. Save-Version 11 ergänzt Voice mit Migration älterer Charakterdaten auf 1,0. Definierte Fakten
sind nicht automatisch allen Figuren bekannt. Ein universelles Ermittlungs-/
Puzzleframework mit Beschuldigung, Gerüchten oder Wahrheitseinstufung existiert nicht.

Die Banditenquest besitzt `not_started`, `active`, `ready`, `completed`.
Annahme führt zu active, bestätigte Banditenniederlage zu ready, geprüfte Abgabe
zu completed. Sieg vor Annahme ist erlaubt; späte Annahme setzt ready nicht zurück.
Abschluss/Belohnung erfolgen einmalig und gemeinsam. Alte Flags bilden eine
monotone Kompatibilitätsbrücke. Migration erzeugt keine rückwirkenden Belohnungen
oder Ereignisse. Beliebige Quest-IDs erhalten nicht automatisch diesen Ablauf.

*Offen:* weitere konkrete Quest, mehrere Ziele/Reihenfolge/Alternativen,
Abbruch, Fehlschlag, Wiederholbarkeit und Umgang mit Questgegenständen.

== Speichern, Laden und Levelwechsel

*Umgesetzt mit bekannten Grenzen.* `WorldSaveStore.VERSION` ist *14*.
Writer/Reader, Typ-/ID-Prüfung und Migration bilden einen Vertrag. Schreiben:
temporäre Datei, Prüfung, Ersetzen; maximale Dateigröße 8 MiB.

```text
| Schemaeinführung | Inhalt |
| 4 | Händlerbestände |
| 5 | persistente Weltereignisse |
| 6 | Banditenquestzustand |
| 7 | aktive Party/Reihenfolge |
| 8 | Kartenerkundung |
| 9 | Itemkampfwert, Talent-ID, Bruchchance |
| 10 | explizite Rüstungskennzeichnung |
| 11 | Charakterstimme `voice`, ältere Spielstände erhalten 1,0 |
| 12 | Waffenreichweiten und Munition |
| 13 | Körperprofile, Trefferzonen und örtlicher Rüstungsschutz |
| 14 | Rüstungs-Richtungsfaktoren; ältere Spielstände erhalten Profilstandards |
```


Unterstützte Altstände werden mit definierten Standardwerten übernommen;
Versionen 1–7 starten ohne entdeckte Karte, alte Items ohne Rüstungsfeld mit false.
Unbekannte Zukunftsversionen/beschädigte Daten werden abgelehnt. Gespeicherte
Händlerangebote übernehmen geänderte Vorlagen nicht automatisch.

`GameState.load_game(path)` prüft einen Kandidaten vor dem Szenentausch und baut
dessen Welt auf. Datei-/Versionsfehler erhalten die Sitzung; erkennbare Aufbaufehler
können die vorherige Welt restaurieren. Kampf, Pause, Interaktion und paralleles
Laden sperren den Einstieg. Haupt-/Spielmenü teilen SaveLoadMenu: neue manuelle
Dateien unter `user://saves/`, auch bei gleichem Namen, Suche, Seiten, Bestätigung
und Fehleranzeige. Autosave/Löschen/Umbenennen/Überschreiben über UI sind offen.

Nicht gespeichert werden aktive Kämpfe/Dialoge, laufende Coroutines/Signals,
UI-Zustände, Physikgeschwindigkeit, Musikposition/Bedrohungen und Simulationsuhr.
Sequence-Flags sind speicherbar, aktive Sequence-Cursor nicht.

Ausgangs-Areas verbinden Level1Ep1 und MonsterLair-Level1 mit Ziel-/Arrivalprüfung
und Fade. Nur der Leader löst aus; nach Aufbau muss er zuerst außerhalb des
Ausgangs gewesen sein. Übergang führt die Party am Ziel zusammen; normales Laden
behält gespeicherte Positionen. Die alte Zusage vollständig getrennter
Banditenidentitäten wird nicht übernommen: Die Höhlenszene hat keine eigene
Gegner-ID-Override. Der aktuelle Levelwechseltest meldet sechs Fehler bei Identität
und Speichern/Laden; unter Windows fehlen außerdem seine `/tmp`-Speicherpfade.

== Kamera, Grafikoptionen und Audio

*Umgesetzt.* CameraSystem besitzt die Weltkamera: Leader-Follow, schräger
Blick, Look-Ahead, Glättung, Zoom, Levelgrenzen, Dialogshots und Kampforbit/-schnitte.
Standard: Abstand 8, Höhe 6, Pitch −45°, Glättung 5, Vorausschau 3.
Charaktere stellen Marker, keine zusätzlichen Weltkameras bereit.

Dialogmarker: Close/Medium/Wide/Profile/OverShoulder unter DialogueCameraPoints;
Eyes/Head/Mouth unter DialogueLookTargets. Marker unterstützen Gewicht, Tags,
FOV und Transition. Fehlende Marker erhalten Fallbacks. Random filtert passende
Tags als Alternativen, dann gewichtet; zuletzt gewählte Einstellung wird nach
Möglichkeit übersprungen. Ende/Abbruch stellt die gültige Basiskontrolle wieder her.
Tags etwa `[\\#camera=close,look=eyes]`, `[\\#close]`,
`[\\#camera=random,shots=emotional+intimate]`; Mutation
`do request_shot("close", "player", "eyes")`.
FOV 0 behält den Wert, negative Transitiondauer nutzt den Systemstandard.
CameraEventHub meldet shot_changed, transition_finished und control_returned;
ein abgebrochener Tween ist kein erfolgreicher Transitionabschluss.

Grafikoptionen unter Menü → Optionen wirken sofort und liegen lokal in
`user://graphics.cfg`, unabhängig von Saves. Standard Hoch/Hoch/100 %;
frühere Bool-Präferenzen werden übernommen.

```text
| Einstellung | Hoch | Einfach | Aus |
| Party-Sichtfenster | weiche Öffnungen per angepasstem dmlary-VisualShader | verdeckende Wandzellen/Meshes hart ausblenden, ohne Cutout-Shader | unveränderte Wände |
| Schatten | ursprüngliche Lichtparameter | harte Sonnenschatten, eine Projektion, höchstens 30 Meter; keine Punkt-/Spotlichtschatten | keine dynamischen Lichtschatten |
```


Unabhängige *3D-Auflösung 100/85/70/50 % pro Achse*; 70 % bedeutet 49 % der
Bildpunkte. Die UI bleibt scharf. Beleuchtung und vorhandene Schatten-Sprites
unter Figuren bleiben erhalten.

Einfaches Sichtfenster prüft mit 10 Hz gecachte Mesh-Grenzen samt Zellrotation,
Skalierung und Mesh-Versatz. Brust-, Kopf- und seitliche Sichtlinien erfassen
mehrere Wandlagen. Laufboden unter den Füßen und Wände hinter Figuren bleiben
sichtbar. Unsichtbare Zellvarianten behalten Kollision/Navigation; Moduswechsel
und Abbau stellen Originalzustände wieder her. Statische Zellgeometrie bleibt
bis Modus-/Levelwechsel gecacht; Aufpoppen/0,1 Sekunden Verzögerung sind möglich.
Hoch unterstützt bis zu 64 sichtbare Mitglieder mit Strahltests/Kapselshader und
Materialkopien. Der frühere Player-X-Ray-Zweitpass ist nicht der aktuelle Ansatz.
Vendor-Originale bleiben unverändert. Abschalten half auf Iris Xe/M4; der
zusätzliche FPS-Gewinn der einfachen Stufe wurde noch nicht quantifiziert.

Die oben beschriebenen Musikregeln sind umgesetzt. Die laufende Bedrohungsliste
ist Sitzungszustand. Hörprüfung der tatsächlichen Lautstärken/Mischung bleibt nötig.
Schrittgeräusche wählen Oberflächen per Boden-Ray zum Schrittzeitpunkt.
FootstepSounds enthält Gras, Stein, Holz, Sand, Wasser, Metall, Erde, Schnee,
Default. `surface_type`-Metadaten funktionieren; Gruppen-Fallbacks sind konkret
für grass/stone/wood/water vorhanden, nicht pauschal für jeden Soundtyp.
FootstepPlayer nutzt Intervalle 0,35/0,25 Sekunden, Raylänge 2, Pitchvariation 0,1;
Methoden start_walking(bool), stop_walking(), set_sprinting(bool), play_step().

*Hauptmenü umgesetzt:* MainMenu.tscn startet mit Logo, Musik, Neues Spiel,
Spiel laden, Kampfsimulation und Beenden. Drei leere Platzhalterräume pale_yellow,
red und dark_blue vertreten die geplanten Titelhintergründe. Kamerafahrt und
Wechsel nach 24 Sekunden mit je 3 Sekunden Aus-/Einblenden sind konfigurierbar.
Main_Theme_Reprise.mp3 ist vorhanden und loopt. Wald/Thronraum/Dungeon als fertig
gestaltete Titelszenen und ein zusätzlicher Optionsknopf bleiben geplant/offen.

= Sequences: Umsetzung und weiterer Plan

== Aktuell ausführbarer Kern

*Teilweise umgesetzt.* SequenceManager unter MainGame/Systems besitzt Catalog,
Parser/Diagnosen, CommandRegistry, Runner/Context, einmalige Handles, Pause/Cancel,
exklusiven Run und eigene Input-Lease. Fremde Sperren, Kampf/Pause oder nicht
bereite Welt verhindern Start; nichtleere Actor-Bindings werden abgelehnt.

```text
sequence sequence_mvp version=1 content_version=1 once=false
wait 2.0
set flag="sequence_mvp_done" value=true id=mark_demo
end code="demo_completed"
```

Nur Header und *wait/set/end/abort* sind ausführbar. UTF-8/BOM, LF/CRLF,
Kommentare außerhalb von Strings und Escapes sind unterstützt. Catalog-IDs,
Parameter, Typen, Flags, Effekt-IDs und Startkarte werden validiert; unbekannte
oder spätere Commands vor Start abgelehnt. EOF ersetzt kein end/abort.
wait erlaubt 0–3600 Sekunden; 0 gibt mindestens einen Frame ab.

API: `MainGame.instance.sequence_manager.start(id)` liefert ein Dictionary mit
accepted, run_id, error_code, message; accepted ist keine Completion.
cancel/pause/resume verwenden die Run-ID; Signals melden Start/Abschluss/Fehler.
Debugdemo wartet zwei Sekunden und setzt sequence_mvp_done; sie startet nicht
automatisch. once=true nutzt vorläufig sequence_completed.<id> als Bool-Flag.
Abbruch/Fehler verbrauchen keine Completion; ausgeführte Weltänderungen bleiben.
Effekt-IDs sind bislang nur innerhalb eines Runs idempotent. Rohe .sequence-Dateien
unter src/resources/sequences werden über das projekteigene Exportplugin aufgenommen.
Es gibt noch keine gespeicherten aktiven Sequences, Checkpoints oder Resume.

== Geplante Phasen und Verträge

*Geplant, keine aktuelle DSL.* Sequences sollen vorhandene Spielsysteme
orchestrieren, keine zweite Runtime für Dialog/Kampf/Saves werden.

```text
| Phase | Lieferumfang | Status |
| 0/1 | Bestand, MVP-Parser/Runner/Handles, Kontrolle, Demo/Export | Kern vorhanden; keine Abnahme des Endziels |
| 2 | Marker/Manifeste, LiveActors, Bind/Spawn/Despawn, Bewegung/Animation, Blasen, korrelierte Dialoge, Parallel-all-Join/Claims | geplant |
| 3 | korrelierter Kampfstart/Ergebniszweige, atomare Belohnung, Recovery | geplant |
| 4 | Ortswechsel, Checkpoints, vollständige Welt+Continuation-Snapshots, Migration | geplant |
| 5 | typisierte Expressions, Bedingungen, Labels/Goto, Budgets | geplant |
| 6 | Kamera-/Audioadapter, Priorität/Besitz, Shots, Crossfade/SFX | geplant; vorhandenes MusicSystem erweitern |
| 7 | Validator, Editorhilfe, Manifeste, Debug-Step/Trace, sichere Simulation | geplant |
| 8 | konsolidierte Fehler-, Export-, Migrations- und Recoveryabnahme | geplant |
```


Geplante Befehlsfamilien: actor/spawn/despawn/move/face/animate/bubble/dialogue,
parallel/endparallel, camera/music/sfx, scene/effect/checkpoint/battle/endbattle,
Labels/goto, let, if/elif/else/endif. Keine beliebigen Nodepfade, Methoden oder
GDScript-Ausdrücke aus Text; nur registrierte IDs und geprüfte Adapter.
Ankunft, Banditenüberfall, Shalkas Warnung und Kundschafterbericht sind geplante
Beispielszenarien und benötigen eigene Ressourcen/Marker, keine vorhandenen Demos.

*Kontrollflussziel:* typisierter AST, Präzedenz Klammern/Queries, not,
Vergleich, and, or; Kurzschluss. Queries für Bool-Flags, aktive Party,
figurenbezogenes Wissen, geprüfte Quests, lokale Werte und Actor-Existenz.
Fehlende IDs/Typen sind Fehler; keine beliebige String-/Bool-Konvertierung.
Labels, Blockgrenzen und alle Sprungziele werden geprüft. Instruction-/Retrybudgets
verhindern Endlosschleifen. EOF ist kein stiller Erfolg.

*Actorziel:* LiveActorRegistry löst aktuelle Verkörperungen eindeutig per ID
auf; CharacterRegistry bleibt Datenquelle. SequenceMarker/Map-Manifeste definieren
Position, Arrival, Kamera, Blickziel und Zone. Bewegung übernimmt StateMachine/
Follow kontrolliert und nutzt 3D-Physik: ARRIVED/UNREACHABLE/TIMEOUT/ACTOR_GONE/
CANCELLED. Kein Teleport durch Wände. Bind spawnt nicht implizit. Temporäre Actors
gehören dem Run und werden bereinigt; Welt-Actors brauchen Deskriptor/Restore.
Fremde Figuren werden nicht beiläufig despawnt. One-shot-Animationen brauchen
korrelierten Abschluss, Loops eine endliche Haltezeit.

*Parallelitätsziel:* gemeinsamer Preflight, all-Join, ein Kindfehler canceliert
Geschwister. Keine frei weiterlaufenden Jobs oder verschachtelten Parallelblöcke.
Exklusive Claims schützen Bewegung/Animation, Blasen, Weltkamera und Musik.
Dialoge, Kämpfe, Ortswechsel, Checkpoints und persistente Effekte sind Barrieren.
Resultat vor Abschluss-Signal setzen; Run-/Command-/Request-ID und Generation
wehren fremde/doppelte/verspätete Signale ab. Cleanup gibt nur eigene Kontrolle frei.

*Dialog-/Präsentationsziel:* Blasen ohne Antwortwahl; volle Gespräche über
DialogueSystem, getrennte Single-Titel-/Themenmodi und Abbruchergebnisse.
Fremdes dialogue_ended beendet keinen Command. Kampfabsichten werden kontrolliert
an den Runner übergeben. CameraSystem bleibt einziger Kameraschreiber; vorgesehene
Priorität Combat, Dialog, Sequence, Gameplay. Musikscope Sequence/Welt restauriert
zulässige Absichten, SFX-One-shots enden/canceln kontrolliert. Phantom Camera ist
eine optionale Adapteralternative, GDrama eine Workflowreferenz; keine neue Pflichtabhängigkeit.

*Kampfziel:* Accepted/Rejected-Start mit Request-/Session-ID und festgehaltener
kontrollierter Partyperspektive. Pflichtzweige WIN/LOSE/FLEE/ABORT/default,
kein implizites Fall-through. Beidseitiger Ausfall benötigt ABORT-Policy.
Ein Fluchtwurf ist kein terminales FLEE, Gegnerflucht nicht automatisch WIN.
Nur korreliertes WIN erlaubt atomare Encounterbelohnung. Doppelte/fremde Signale
verschieben keinen Cursor und zahlen nicht mehrfach. Regiekontrolle wird für
Kampfzüge übergeben und vor Ergebnisfortsetzung zurückgenommen.

*Persistenzziel:* vollständige Welt und Continuation in derselben Save-Datei
committen. PREPARED enthält Vor-Kampf-Welt, RESULT_READY Nach-Kampf-Welt/Ergebnis.
Crash während Kampf lädt sicheren Vorzustand; RESULT_READY wiederholt keinen Kampf.
Checkpoints nur außerhalb laufender Aktionen/Blöcke; Inhalt: Run/Script-ID,
Version/Hash, Resume-Label, Locals, Actorbindungen/-deskriptoren, Effekt-IDs,
Phase/Kampfkorrelation. Keine Coroutines/Signalverbindungen/Lock-Zähler speichern.
Scriptänderungen brauchen kompatible Migration oder Recovery.

Vor Transition Ziel/Arrival prüfen, Vorzustand committen, kontrolliert tauschen,
Actor-/Marker-/Kamera-/Physikbereitschaft bestätigen und Zielzustand committen.
Schreibfehler verhindern Kampfstart bzw. Ergebniszweig. Restore baut Welt zuerst
auf, prüft Content und erwirbt neue Leases vor erneuter Triggerfreigabe.
Saveänderungen gehen vom tatsächlichen Schema 11 aus; alte Planangaben 8→9
sind keine reservierten Versionsnummern. Weltänderung, Event und angewendete
Effekt-ID sollen atomar sein; einmalige Quest-/Encounter-Rewards brauchen Schutz
auch zwischen Runs. Manuelles Speichern außerhalb sicherer Grenzen bleibt gesperrt.

*Geplante Abnahme:* Parser-/Typ-/Flowfixtures, immediate Handles, Pause/Cancel,
Claims/Timeouts, Actorverlust, alle Kampfausgänge, fremde/doppelte Signale,
Savefehler vor/nach Commit, Contentkonflikte, einmalige Rewards, Export und
vollständige Rückgabe eigener Kontrolle. Debug-Step/Trace/Validator verwenden
vorhandene Testkonventionen. Skip braucht vorher eine ausdrückliche Storyeffekt-
und Barrierenregel; es ist keine MVP-Funktion.

= Geplante datengetriebene Charakterregeln

*Entwurf, nicht im Spiel aktiv.* src/data/character_rules enthält 32 Beispiele:
7 Attribute, 7 Talente, 6 Bedingungen, 6 Aktionen und 6 Regeln. Ein Importer fehlt;
Entfernen von example_draft aktiviert nichts. Ein späterer Import erweitert
vorhandene Kataloge/WorldRules statt sie parallel zu duplizieren.

== Format und Bedingungen

Gemeinsame Felder: format_version=1, id, name, description, status=example_draft.
Dateiname und ID stimmen überein. IDs beginnen mit Kleinbuchstaben und enthalten
Kleinbuchstaben, Ziffern, Unterstriche. Formatversion ist keine Saveversion.
Individuelle Stufen/XP bleiben im Charakterspielstand.

Attributentwürfe enthalten Basiswert, Minimum und additive Talentbeiträge;
Talente attribute_id, +1 pro Stufe, 100 XP und vorgeschlagenes Cap 20.
Neue IDs schwertkampf/ueberzeugen dürfen schwertkampf_klassisch/
rhetorik_ueberzeugen nicht unbemerkt verdoppeln: Wiederverwendung oder Migration.

Bedingungen kombinieren all/any/not oder condition_ref mit condition_id.
Keine Mischung von Gruppe und Einzelprüfung; leere Gruppen/Zyklen/ungültige
Kontexte sollen Fehler sein, auch unter not. Operatoren >, >=, ==, !=, <=, <;
„über 10“ ist strikt > 10. actor/target und Beziehungsrichtung sind explizit;
diese Kontextsyntax ist nicht direkt an WorldRules übergebbar.

Geplante Prüfarten: Talentstufe, effektives Attribut, ausgerüstetes Itemtag,
Figurenwissen, Bool-Flag, gerichtete Beziehung, aktuelle Ressource,
Ressourcenverhältnis und aktiver Status. Ein Verhältnis darf negativ oder >1
sein; Basis ≤0 ist ungültig. Tags und Status benötigen Laufzeitunterstützung.

```text
| Beispiel | Vorgesehene Voraussetzung |
| Charmante Überzeugung | Flirten >10, Überzeugen >10, Präsenz >5 |
| Doppelhieb bereit | Schwertkampf ≥10, Gewandheit >5, Schwert in einer Hand |
| Friedliche Verhandlung | soziale Kombination oder Überzeugen ≥8 plus Passwort; kein Alarm, Gegenüber mindestens neutral |
| Zwei Schwerter bereit | Doppelhieb, Beidhändigkeit ≥6, Schwert in jeder Hand |
| Notfall-Schutz | SP höchstens 25 % Basis, KP mindestens 4, Schutzstatus nicht aktiv |
| Arkaner Fokus | Magiekunde ≥8 und Meditation/Bewusstsein oder arkanes Wissen; nicht verwirrt |
```


Additive Wechselwirkung: Flirten 11 + Überzeugen 11 ergibt bei Präsenz-Basis 1
bereits 23. beispiel-Facts/-Flags/-Dialogoptionen sind Platzhalter; ein Messer
ist nicht automatisch als Schwert getaggt.

== Aktionen, Status und Ersetzungsregeln

Aktionsentwürfe definieren Voraussetzung, Zieltyp, Sicht, geplante Distanzgrenze,
Gesamtkosten und geordnete Effektschritte. Doppelhieb: zwei Treffer mit je
Ausweichen/Robustheit, Kosten einmal, Stopp bei ausgeschiedenem Ziel. Kreuzhieb:
erster Treffer Körperkraft-, zweiter Gewandheitsgenauigkeit. Fokussierter Feuerstoß
ist eine weitere kostenpflichtige Aktion. Eiserner Wille/Ermutigen sind
Statusbeispiele, keine durch JSON bereits aktivierten Spielaktionen.

Geplante Dauer zählt spätere beendete eigene Züge des Empfängers;
refresh_duration erneuert, stapelt aber nicht. Folgen für SP-Basis, aktuelle
Vorräte und Todesgrenze beim Ablauf bleiben offen. Ziel/Voraussetzung/Reichweite/
unterstützte Effekte sollen vor Kostenabzug geprüft werden. Zufälliges Ausweichen
ist dagegen ein reguläres bezahltes Ergebnis.

Regeln verbinden Bedingung, Priorität und effect für dialog_options oder
combat_action_selection: offer_dialog_option, offer_action, replace_action.
Höchste passende Ersetzungspriorität gewinnt; Gleichstand ist Konfigurationsfehler,
keine rekursive Kette. Fehlende Ausgangsaktion wird nicht durch Ersetzung erzeugt.
Doppelhieb Priorität 10, Kreuzhieb 20. Voraussetzungen wirken dynamisch, lernen
nichts permanent. Eiserner Wille wird nur angeboten, nicht automatisch ausgelöst;
Ermutigen hat keine Freischaltungsregel. Späterer Import braucht Syntax-/Referenz-/
Zyklentests und echte Laufzeitintegration, keine bloße JSON-Validierung.

= Offene Entscheidungen und nächste Schritte

*Offen; kein automatischer Implementierungsauftrag.* Die vorhandenen Ziele
werden nicht als fertig ausgegeben. Wichtige Folgeentscheidungen sind:

```text
| Bereich | Noch zu klären oder umzusetzen |
| Charakter | Merkmalsmodifikatoren, fünf Talentplätze, Cap 20, Lehrer/Aktions-XP und freie XP |
| Vitalwerte | Regeneration/Nahrung, negative Verletzungen, Heilungslimit, Wiederbelebung, KP unter 0 |
| Kampf | Distanzen, Trefferzonen, Schwachpunkte, taktische Aktionen, Nebenhand/Zweihand, Beute, Recovery und beidseitiger Ausfall |
| Soziales/Puzzle | Überreden, Einschüchtern, Beschuldigung, kombinierbare Lösungen und Puzzlemodell |
| Quests | weitere konkrete Quest, Abbruch/Fehlschlag, mehrere Ziele/Alternativen und Wiederholbarkeit |
| Party/Umwelt | Rekrutierung/Entlassung, zusätzliche Rollen, Formation, Händetragen, Materialreaktionen, Wahrnehmung |
| Präsentation | echte Titelszenen, Sprachauswahl, Highlightwahl, vollständige Controllerbedienung |
| Persistenz | Saveverwaltung/Autosave, Sequence-Checkpoints/Resume, belastbare Levelidentitäten |
| Qualität | quantitative Iris-Xe-/M4-FPS-Messung, Hörprüfung, physischer Controller und Exportabnahme |
```


Eine neue Quest benötigt Auftraggeber/Ort, Voraussetzungen, Ziele, Reihenfolge/
Alternativen/Vorabfortschritt, Abgabe, Belohnungsempfänger, Questgegenstände und
Abbruch-/Fehlschlag-/Wiederholungsregeln sowie konkrete Dialoge/NPCs/Items.
Nur tatsächlich benötigte Übergänge ergänzen, WorldRules verwenden und
Migration/Wiederholungsschutz prüfen.

Die frühere allgemeine Architekturberatung war kein beschlossener Ersatz des
XP-Systems und kein Verbot, das vorhandene Kampfsystem weiterzuentwickeln.
Ein kleiner verknüpfter Puzzle-/Dialog-/Quest-Slice ist eine Entwicklungsrichtung;
vorgeschlagene Stadt-/NPC-Zahlen sind keine freigegebene Inhaltsanforderung.

= Technische Quellen und Prüfstand

== Verbindliche Anlaufstellen

```text
| Aufgabe | Aktuelle Quelle |
| Aufbau | [MainGame](../src/core/main_game/main_game.gd) |
| Charakterwerte/XP | [Charakterbogen](../src/resources/characters/character_sheet.gd), [Berechnung](../src/gameplay/character/character_sheet_calculator.gd), [Registry](../src/core/character_registry.gd) |
| Weltregeln/Saves | [WorldRules](../src/core/world/world_rules.gd), [SaveStore](../src/core/world/world_save_store.gd), [WorldLoader](../src/core/world/world_loader.gd) |
| Kampf | [Manager](../src/core/managers/combat_manager.gd), [Session](../src/gameplay/combat/engine/combat_session.gd), [Resolver](../src/gameplay/combat/engine/combat_resolver.gd), [Beziehungen](../src/gameplay/combat/relationships/relationship_service.gd) |
| Fenster/Designsystem | [GameWindows](../src/ui/menus/game_windows.gd), [Theme-Regeln](../src/ui/theme/README.md) |
| Kamera/Grafik/Musik | [CameraSystem](../src/core/systems/camera_system.gd), [OcclusionVisual](../src/gameplay/character/player/occlusion/occlusion_visual.gd), [GraphicsSettings](../src/core/autoload/graphics_settings.gd), [MusicSystem](../src/core/systems/music_system.gd) |
| Sequences | [SequenceManager](../src/core/sequences/sequence_manager.gd), [CommandRegistry](../src/core/sequences/sequence_command_registry.gd) |
| Beispieldaten | [JSON-Dateien](../src/data/character_rules/README.md) |
```


Globales NE_Theme, NEColors, NEDimensions, NETypography und Cuprum sind verbindlich.
Standard-Controls und bestehende Komponenten verwenden, keine dekorativen
StyleBox-Ersatzstile. Modale Flächen dimmen mit SCRIM; Panel-Innenabstände über
MarginContainer/PANEL_MARGIN. Das lokale Dialogue-Manager-Theme bleibt unverändert.

States verwenden die tatsächlichen kleingeschriebenen Methoden enter, exit,
process, physics, handle_input. CombatWait/Turn/Move übersteuern die normale
Erkundung. Hitbox empfängt über TakeDamage/Damaged, HurtBox löst Area3D-Kontakt
aus; dies begründet keine parallele Echtzeitkampfarchitektur.

== Umfang und Grenzen der Prüfung

Alle zentralen Textdokumente unter docs wurden gelesen und mit den relevanten
Implementierungen abgeglichen. Fachliche READMEs unter src bleiben komponentennah;
sie werden nicht zu einem zweiten zentralen Designbestand ausgebaut.
Die Bilder unter res sind Designskizzen, keine Nachweise aktueller Darstellung.

Vor dieser reinen Dokumentationskonsolidierung nachgewiesen:
test_graphics_settings mit 33 fehlerfreien Prüfungen und gerenderten Verdeckungs-
Vergleichsbildern, test_movement_cutout mit 15 fehlerfreien Prüfungen.
Keine erneute vollständige Laufzeitabnahme sämtlicher Systeme in diesem Schritt.
Der aktuelle test_level_transitions meldet sechs Fehler; der historische
test_party_state-Bericht nennt zusätzlich eine Kinderzählung, die OcclusionVisual
als Begleiter mitzählt. Dieser alte Befund ist keine neue Laufzeitprüfung.

Weitere vorhandene Tests für WorldState/Rules, Speichern/Loader, Wissen/Quest,
Party/Dialog, Inventar/Handel/Diebstahl, Kampf, Karte und Sequences sind
Prüfeinstiege und werden nicht pauschal als bestanden markiert.
Testkonvention: Szenen unter src/debug/tools, Prüfzähler, Prozess-Exitcode, z. B.:

```text
godot --headless --path . res://src/debug/tools/test_graphics_settings.tscn
godot --headless --path . res://src/debug/tools/test_sequences.tscn
```

Neue Scripts benötigen Import/Klassenindex, Rohdateien wie .sequence zusätzlich
Exportprüfung. Saveänderungen verlangen Writer/Reader/Validierung/Migration
gemeinsam. Engine-/Addon-Upgrades oder Drittanbieteränderungen sind keine
beiläufige Voraussetzung. Testpfade müssen zum Betriebssystem passen;
historische /tmp-Pfade sind unter Windows nicht automatisch vorhanden.
