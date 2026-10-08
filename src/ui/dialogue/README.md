# Vollbildgespräche

`DialogueSystem.start_npc_dialogue` öffnet `conversation_ui.gd` unter
`MainGame/UI/DialogueRoot`. Die Ansicht belegt die komplette Spielauflösung und
verwendet ausschließlich das globale Theme und dessen Tokens.

- Links: zuletzt sprechender NPC bzw. Gast, zu Beginn der angesprochene NPC.
- Rechts: zuletzt sprechendes aktives Partymitglied, zu Beginn die angesprochene
  Spielerfigur (im freien Spiel der aktuelle Party-Anführer).
- Mitte: scrollbarer Verlauf mit Namen und links/rechts ausgerichteten Beiträgen.
  „Weiter“ zeigt die nächste Zeile; native Antwortoptionen verzweigen den Dialog.
- `=> END` beendet einen Zweig und zeigt die NPC-Themen. Der Verlauf bleibt stehen.
  „Gespräch beenden“ oder Escape schließt das Fenster. Handel übergibt an den
  Laden; ein ausgelöster Angriff beendet das Gespräch und startet den Kampf.

## Sprecher und Porträts

Dialogzeilen können Anzeigenamen oder Charakter-IDs verwenden. Bei gleichen
Namen den eindeutigen Tag verwenden, beispielsweise:

```text
Bandit: Ihr kommt hier nicht vorbei. [#subject=bandit_01]
Shalka: Lass uns zuerst reden. [#subject=shalka]
{{player.get_display_name()}}: Was verlangst du?
```

Die Seite ergibt sich aus der **aktiven** Party, nicht aus dem Namen oder der
Klasse des Sprechers. Beiträge anderer Mitglieder wechseln nur das rechte Bild,
weitere NPCs nur das linke. Der Partner auf der anderen Seite bleibt sichtbar.
Zeilen ohne Namen gelten als Erzählertext und ändern die Porträts nicht.

Partyporträts kommen aus `CharacterResource.get_portrait()`. Für NPCs lässt sich
im Inspector an deren `NPCData` unter **Gesprächsfenster → Portrait** ein Bild
zuweisen. Ohne Override gilt ebenfalls die vorhandene Portrait-Dateikonvention.
Fehlt ein Bild, erscheint der Anfangsbuchstabe mit Name und erklärendem Tooltip.
Es werden keine falschen Gesichtsbilder anderer Charaktere eingesetzt.

## Themen pro NPC einrichten

Unter **NPCData → Gesprächsfenster → Dialogue Topics** Einträge vom Typ
`NPCDialogueTopic` hinzufügen:

- `label`: sichtbarer Knopf, etwa „Name“, „Job“ oder ein gelerntes Stichwort.
- `title`: Titel in der zugehörigen `.dialogue`-Datei, etwa `name` oder `job`.
- `required_fact_id`: optional eine Wissens-ID. Die Option erscheint nur, wenn die
  tatsächlich sprechende Spielerfigur diese Information bereits kennt.

Ungültige oder unbekannte Ziel-Titel werden nicht als Option angeboten.
`can_trade` und `shop_id` ergänzen „Handeln“, `can_fight` ergänzt „Angreifen“.
Besiegte NPCs bieten diese beiden Aktionen nicht an. Native Dialogantworten
bleiben einschließlich ihrer Bedingungen und `do`-Anweisungen erhalten.

Der Händler besitzt Name-/Job-Themen. Elara besitzt „Name“ sowie „Bandit“,
sobald die Spielerfigur `bandit_location_west` gelernt hat. Auswahlantworten
werden im Verlauf auf der Partyseite festgehalten.

## Lebenszyklus und Prüfung

Die Sitzung besitzt genau eine Eingabesperre; Abschluss, Fensterabbau und Angriff
geben nur diese Sperre frei. Parallele Gesprächsstarts werden abgewiesen.
Auswahl und Weiter sind während einer laufenden Dialogmutation gesperrt.
Das Plugin wird über dessen aktuelle `DialogueResource.titles`-API angebunden.
Ein Dialogende des Plugins schließt nicht automatisch die Themenauswahl.
Der Verlauf gilt für das aktuelle Gespräch und wird nicht im Spielstand abgelegt.
Kurze Gespräche außerhalb des Fensters bleiben einer späteren Aufgabe vorbehalten.

Tests:

- `res://src/debug/tools/test_conversation_ui.tscn`: Layout, Porträts, Seitenwechsel,
  Themen, individuelles Wissen, Shalka als Sprecherin, Handel, Kampf und Sperren.
- `test_dialogue_context.tscn`, `test_combat_quest.tscn`, `test_gameplay_journey.tscn`:
  echte Questannahme, Belohnung, Gesprächskontext und gesamter Spielablauf.
- `test_conversation_ui.tscn -- --visual` erzeugt bei aktivem Renderer
  `/tmp/conversation-ui-preview.png` und `/tmp/conversation-ui-small.png`.
