# Necota: Datengetriebenes Ingame-Sequence-System

**Spiel:** Peters *Nascent Eternity: Call of the Abyss (Necota)*  
**Dokument:** technische Zielspezifikation und Implementierungsleitfaden  
**Stand:** 1. Oktober 2026 · DSL-Version 1  
**Untersuchtes Projekt:** `/Users/hapetse/Dev/NECOTA2D`, HEAD `1a1320a`  
**Status:** Technische Zielspezifikation; der erste MVP-Schritt ist umgesetzt. Weiterführende APIs und DSL-Befehle sind noch geplant.

## Bereits umgesetzter erster Schritt

Der Sequence-Kern ist in NECOTA2D integriert: Manager unter MainGame/Systems,
Parser/Commandschema, Runner/Context/Handles, Catalog, Besitzer-Leases,
`wait`, `set`, `end`, `abort`, Debugdemo und Exportplugin für rohe Textdateien.
Einmalige Completion verwendet vorläufig reservierte WorldState-Bool-Flags;
Checkpoints, Kampf-Resume, Actors und Dialog-Commands sind weiterhin das Endziel.
Die folgende Spezifikation beschreibt dieses vollständige Endziel; aktuelle
Verwendung und Grenzen stehen im Projekt unter `src/core/sequences/README.md`.

## 1. Ziel und verbindliche Grundentscheidungen

Cutscenes werden als menschenlesbare UTF-8-Textdateien mit der Endung `.sequence` geschrieben. Sie orchestrieren Figuren, Textblasen, Gespräche, Bewegung, Animation, Kamera, Audio, Ortswechsel und Kämpfe. Autoren schreiben keine GDScript-Ausdrücke und greifen nicht auf beliebige Nodes oder Methoden zu.

Der **SequenceManager** koordiniert Starts und Lebensdauer. Ein **SequenceRunner** führt ein kompiliertes Script aus. Beide sind Regie, keine zweite Spielsimulation: Charakterdaten, Kampflogik, Weltzustand, Dialoge und Speicherung bleiben in den bestehenden Systemen. Adapter übersetzen stabile Sequence-Verträge in deren konkrete APIs.

Verbindliche Entscheidungen für Version 1:

- Ein exklusiver Story-Runner pro MainGame. Weitere Startversuche liefern `BUSY`; keine unsichtbare Warteschlange. Parallele Aktionen finden innerhalb dieses Runners statt.
- SequenceManager ist ein Node unter `MainGame/Systems`, **kein neuer Autoload**. Er überlebt Levelwechsel, aber nicht den Austausch von MainGame beim Laden eines Spielstands. Wiederaufnahme erfolgt dann aus WorldState.
- Kämpfe bleiben in der normalen Spielwelt. Das Projekt hat bereits CombatManager/CombatSession; ein separater BattleManager oder eine separate Kampfszene wird nicht eingeführt.
- DSL referenziert stabile Actor-, Marker-, Ressourcen- und Sequence-IDs. Kartenkoordinaten und NodePaths sind kein Autorenvertrag.
- Gameplay-Effekte werden über GameState/WorldRules ausgeführt. Queststatus wird nicht direkt überschrieben; Wissen bleibt pro Charakter.
- Fortsetzung nach Kampf ist ergebnisabhängig und explizit. Flucht bedeutet niemals automatisch Sieg. Unbekannte Ergebnisse führen in einen sicheren Fehlerpfad.
- Speichern erfolgt ausschließlich an überprüften sicheren Grenzen. Keine Serialisierung von Coroutines, Signals, Nodes oder laufenden Tweens.
- Scriptfehler werden vor dem Start geprüft. Laufzeitfehler beenden den Runner kontrolliert oder gehen zu einem zulässigen Fehlerlabel.
- Addons bleiben hinter Adaptern. Die Necota-DSL ist weder Dialogue-Manager-Syntax noch GDrama-Syntax.

Nicht Bestandteil von Version 1: verschachtelte Sequence-Aufrufe, beliebiges Script-Eval, Mod-Sandbox, Netzwerkreplikation, laufendes Kampf-Save, Zeitleisteneditor und automatisches Überspringen kompletter Storyabläufe. Diese Erweiterungen brauchen eigene Verträge.

## 2. Tatsächlicher Projektbestand und Integrationslücken

Die folgenden Befunde stammen aus den lokal gelesenen Projektdateien. Sie müssen vor der Implementierung erneut gegen den aktuellen Branch geprüft werden.

### 2.1 Spielanker und Welt

`src/core/main_game/main_game.gd` stellt `MainGame.instance`, `World/LevelRoot`, `World/EntityRoot`, `World/EffectRoot` sowie UI-Layer bereit. Die Party bleibt unter EntityRoot bestehen; Level werden ausgetauscht. Das ist der richtige Lebenszyklus für den SequenceManager.

`src/core/managers/level_manager.gd` bietet `level_loaded(level)`, `level_unloaded(path)`, `load_level(path)`, `_load_level(path, arrival_path)`, `request_transition(source, path, arrival)` und `save_world(path)`.

**Lücke:** `_load_level`, `request_transition` und `save_world` lehnen aktive Input-Sperren ab. Eine Sequence besitzt selbst eine Sperre und würde dadurch blockiert. `request_transition` verlangt außerdem eine Area3D des aktuellen Levels. Es ist kein geeigneter Sequence-Einstiegspunkt. Ein Besitzervertrag und ein öffentlicher asynchroner Sequence-Transition-Vertrag sind notwendig; private Methoden nicht direkt aufrufen.

`src/world/levels/base_level.gd` hat `find_spawn_marker(marker_name)`. Aktuell ist dies eine direkte Node-Suche relativ zum Level; es ist noch kein Registry-System für verschachtelte, eindeutige Marker-IDs.

### 2.2 Figuren und Party

`src/core/character_registry.gd` verwaltet CharacterResource-Laufzeitdaten, Vorlagen und stabile `character_id`-Werte. Es ist **keine Registry lebender Actor-Nodes**.

`Playable` hat unter anderem `character`, `bind_character`, `face_world_position`, `set_horizontal_velocity`, `stop_horizontal_velocity` und `update_animation`. Player, NPC, PartyFollower und die StateMachine steuern Bewegung und Animation. CharacterModelAnimator bietet `play_state`, aber noch keinen allgemeinen abbrechbaren One-shot-Vertrag mit Abschlussresultat.

`Party.get_all_members()` und `party.leader` bestimmen die aktuelle Besetzung. IDs wie `dannerman`, `shalka`, `bandit_01`, `lair_bandit_01` und `quest_giver_01` sind im Projekt vorhanden.

**Lücke:** eine LiveActorRegistry, zeitweise Regiekontrolle und ein Move-to-Marker-Vertrag müssen ergänzt werden. CharacterResource nicht für eine Cutscene duplizieren; der Node muss dieselbe autoritative Ressource wie CharacterRegistry verwenden.

### 2.3 Dialog

Dialogue Manager ist bereits als Autoload installiert; `addons/dialogue_manager/plugin.cfg` nennt **3.10.5**. Das Projekt verwendet `src/core/systems/dialogue_system.gd` und `src/ui/dialogue/conversation_ui.gd` statt des Addon-Beispielballoons.

DialogueSystem besitzt `dialogue_started`, `dialogue_ended`, Kameraereignisse und `finish_conversation()`. Der derzeitige Einstieg `_start_npc_dialogue` prüft die globale Input-Sperre. Ein Dialog-`END` führt laut bestehendem Vertrag zur Themenwahl zurück; erst das Schließen beendet die Sitzung.

**Lücke:** Sequence-Dialoge benötigen einen öffentlichen, korrelierten Einstieg und einen Modus `single`, in dem das Ende des gewählten Dialogtitels die Sequence fortsetzt. Textblasen über Actors sind ein eigener kleiner Präsentationsadapter. `start_encounter(_encounter_id)` im DialogueSystem ignoriert heute die Encounter-ID und greift den aktiven NPC an; das ist kein ausreichender Sequence-Kampfvertrag.

### 2.4 Kampf

`src/core/managers/combat_manager.gd` besitzt `trigger_attack(attacker, victim)`, `combat_started(session)` und `combat_ended(session, outcome)`. Aktuell enthält `outcome` nur `losing_side`. CombatParticipantResolver und Beziehungen ermitteln weitere Teilnehmer dynamisch. EncounterData enthält Belohnungsmetadaten, keine Gegnerliste; die Zuordnung zu einem Sieg ist noch offen.

CombatSession behandelt individuelle Flucht und Seitenende. `_check_side_wipe()` meldet eine Seite erst, wenn die andere noch aktiv ist; der Fall, dass beide Seiten ausfallen, hat dort aktuell keinen eindeutigen Endpfad.

**Lücke:** ein vollständiges terminales Ergebnis, Request-/Session-Korrelation, Behandlung beidseitigen Ausfalls und ein einmaliger Abschluss sind nötig. `losing_side` allein unterscheidet Niederlage und Flucht nicht. Dies ist eine Änderung am Kampfsystem, keine Heuristik im DSL-Runner.

### 2.5 Kamera, Audio und Speicherung

`src/core/systems/camera_system.gd` bietet Gameplay-, Dialog- und Kampfführung sowie `begin_cutscene()`/`end_cutscene()`. CameraEventHub meldet Shot-Wechsel, Transition-Ende und Kontrollrückgabe. Ein einzelnes `_cutscene_active`-Boolean ersetzt noch keinen Besitzerstack.

Phantom Camera und GDrama sind in den untersuchten `addons/*/plugin.cfg` nicht installiert. Das bestehende CameraSystem ist die primäre Integration; Phantom Camera ist eine optionale spätere Backend-Alternative.

UIAudio deckt UI-Sounds ab; FootstepPlayer und einzelne AudioStreamPlayer decken lokale Geräusche ab. In den untersuchten Scripts ist kein zentraler Musik-/Cutscene-Audio-Vertrag vorhanden. Ein schlanker Gameplay-Audio-Service wird ergänzt, vorhandene UI- und Schrittgeräusche bleiben zuständig für ihre Aufgaben.

GameState hat Input-Lock-Zähler, Flags, Wissen und WorldRules-Einstiege. WorldState hält Charaktere, Weltobjekte, Platzierungen, Party, Wissen, Quests und Events. WorldSaveStore hat **VERSION 8**, überprüft temporär geschriebene Daten vor dem Ersetzen und unterstützt ältere Versionen. WorldLoader baut MainGame neu auf und kann bei Fehlern die vorherige Welt wiederherstellen.

**Lücke:** WorldState enthält noch keine Sequence-Historie/Continuation. Die Reader-Validierung für Quests ist derzeit ausdrücklich auf `bandit` begrenzt; die DSL darf nicht stillschweigend beliebige neue Questzustände speichern.

## 3. Architektur und Verantwortlichkeiten

```text
Trigger / Interaktion / Quest / Debug-Menü
                    |
             SequenceManager
      Catalog -> Parser -> Validator
                    |
             SequenceProgram
                    |
             SequenceRunner
           SequenceContext
                    |
       CommandRegistry + Handles
                    |
   +----------------+-------------------------+
   | Actors | Dialog | Level | Camera | Audio |
   | Combat | Conditions/Effects | Save       |
   +----------------+-------------------------+
                    |
   bestehende Necota-Systeme / WorldState
```

### SequenceManager

- Nimmt `start(sequence_id, bindings, trigger_id)` entgegen und gibt `StartResult` mit `run_id` oder Fehler zurück.
- Prüft MainGame-Bereitschaft, Startbedingungen, einmalige Completion und Exklusivität.
- Lädt ein unveränderliches SequenceProgram aus dem Catalog; startet und beaufsichtigt den Runner.
- Besitzt Start-/End-Signale, History und den einzigen Wiederaufnahme-Einstieg.
- Bricht vor dem Verlassen von MainGame alle eigenen Handles ab und stellt Kontrolle wieder her.
- Persistiert keine Nodes; schreibt Continuation-Daten über SaveAdapter in WorldState.

### SequenceRunner

- Hält Instruction Pointer, lokalen Kontrollfluss, aktive Handles, Fehler- und Pausezustand.
- Führt Commands über die CommandRegistry aus, wartet auf Handles und verarbeitet Branching.
- Erzeugt keine Gegnerlogik, Dialogzeilen, Inventartransfers oder Kameraalgorithmen selbst.
- Führt ein Cleanup-Register für jede erworbene Sperre, jeden temporären Actor und jede Ressourcenkontrolle.

### SequenceCatalog und SequenceProgram

- Catalog ordnet `sequence_id` einem `.sequence`-Pfad zu; doppelte IDs sind Fehler.
- Weitere typisierte Catalogs ordnen Map-, Dialog-, Actor-Prefab- und Audio-IDs Projektressourcen zu.
- Program enthält DSL-/Content-Version, Content-Hash, Metadaten, Instructions, Labelindex, Markeranforderungen und SourceMap.
- Compilierte Daten sind unveränderlich. Kein Cursor oder Spielzustand in gemeinsam verwendeten Resources.

### Adapter und Services

- `ActorAdapter`: Live-Auflösung, Kontrolle, Spawn/Despawn, Bewegung und Animation.
- `DialogueAdapter`: korrelierte Sitzungen und Textblasen; UI und Addon bleiben hinter diesem Vertrag.
- `SceneAdapter`: Levelwechsel und Readiness-Barriere.
- `BattleAdapter`: Kampfstart, Besitzübergabe, terminales BattleResult und sichere Weiterleitung.
- `CameraAdapter`: Shots, Übergänge und Besitzverwaltung auf CameraSystem.
- `AudioAdapter`: Musik-, Ducking- und SFX-Anfragen an den Audio-Service.
- `StateAdapter`: typisierte Queries und atomare Effekte über GameState/WorldRules.
- `SaveAdapter`: sichere Grenzen, Snapshot-Erstellung, Persistenz und Resume-Prüfung.

Adapter erhalten explizite Service-Referenzen von MainGame. `*.instance` bleibt gegebenenfalls im Adapter als bestehende Kompatibilitätsbrücke, nicht verteilt in einzelnen Commands.

## 4. Vorgeschlagene Dateistruktur

Alle folgenden **neuen** Pfade sind Vorschläge relativ zur Godot-Projektwurzel; sie sind keine Behauptung bereits vorhandener Dateien.

```text
src/core/sequences/
  sequence_manager.gd
  sequence_runner.gd
  sequence_context.gd
  sequence_program.gd
  sequence_parser.gd
  sequence_validator.gd
  sequence_command.gd
  sequence_command_registry.gd
  sequence_handle.gd
  sequence_result.gd
  sequence_continuation.gd
  adapters/
    actor_adapter.gd
    dialogue_adapter.gd
    scene_adapter.gd
    battle_adapter.gd
    camera_adapter.gd
    audio_adapter.gd
    state_adapter.gd
    save_adapter.gd
  commands/
    actor_commands.gd
    dialogue_commands.gd
    scene_command.gd
    battle_command.gd
    camera_commands.gd
    audio_commands.gd
    state_commands.gd
src/gameplay/sequences/
  sequence_trigger.gd
  sequence_marker.gd
  live_actor_registry.gd
  sequence_actor_controller.gd
src/core/systems/game_audio_system.gd
src/resources/sequences/
  sequence_catalog.tres
  asset_catalog.tres
  chapter_01/arrival.sequence
  chapter_01/bandit.sequence
src/ui/sequences/
  speech_bubble.gd
  speech_bubble.tscn
src/debug/tools/
  test_sequence_parser.gd (+ Testszene)
  test_sequence_runner.gd (+ Testszene)
  test_sequence_battle.gd (+ Testszene)
  test_sequence_resume.gd (+ Testszene)
  validate_sequences.gd
addons/necota_sequence_editor/       # erst spätere Editorphase
docs/NECOTA_SEQUENCE_SYSTEM.md
```

Kleine Command-Familien dürfen eine Datei teilen. Kein eigener Manager pro DSL-Verb. Der MVP liest Text über FileAccess; Exportfilter müssen `.sequence` ausdrücklich einschließen. Später kann ein EditorImportPlugin SequenceProgram-Resources erzeugen. Compiler und Validierung müssen in beiden Wegen dieselben sein.

## 5. SequenceContext: Laufzeit und serialisierbarer Zustand

Der Context wird pro Run neu angelegt. Er enthält zwei klar getrennte Bereiche.

**Serialisierbare Daten:**

- `run_id`: einmal erzeugte stabile UUID; bleibt beim Resume gleich.
- `sequence_id`, `dsl_version`, `content_version`, `content_hash`.
- `instruction_pointer`: nur intern für laufende Ausführung; persistente Wiederaufnahme benutzt stabile Labels.
- `locals`: Dictionary primitiver, typisierter DSL-Werte.
- `actor_bindings`: Alias -> Character-ID, plus Bindungsart `existing`/`spawned` und Lifecycle.
- `current_location_id`, `checkpoint_id`, `resume_label`.
- `battle_request_id`, `battle_result`, `phase` bei Kampf-Continuation.
- `applied_effect_ids`, Completion-/Failure-Status und Trigger-ID.
- persistente Actor-Descriptors, falls ein dynamisch erzeugter Actor wiederhergestellt werden muss.

**Nur zur Laufzeit:**

- explizite Service-/Adapter-Referenzen.
- Actor-WeakRefs und Markerindex der aktuellen Levelgeneration.
- Input-, Kamera-, Audio- und Actor-Control-Leases.
- aktive CommandHandles, CancellationToken, Signalverbindungen und Timeouts.
- Cleanup-Stack, Debug-Trace, SourceMap, Pause- und Fehlerstatus.

`player` ist ein erlaubter eingebauter Alias: beim Start wird die aktuelle `party.leader.character.character_id` gebunden. Er bleibt während des Runs stabil, auch wenn später die Führung geändert wird. `party.has(...)` fragt dagegen die jeweils autoritative Partybesetzung ab. Ein benötigter Actor, der beim Resume nicht mehr verfügbar ist, erzeugt einen Fehler; kein stiller Ersatz durch einen anderen Leader.

Persistiert werden keine Resource-Laufzeitkopien des ganzen Spiels im Context. WorldState bleibt die einzige autoritative Welt. Der Context verweist über IDs darauf.

## 6. Öffentliche Zielverträge

Die folgenden Signaturen sind **neu zu implementierende Ziel-APIs**. Konkrete GDScript-Typnamen dürfen den Projektkonventionen angepasst werden, Semantik und Ergebnisse nicht.

```gdscript
# SequenceManager unter MainGame/Systems
func start(sequence_id: StringName, bindings: Dictionary = {},
           trigger_id: StringName = &"") -> SequenceStartResult
func cancel(run_id: String, reason: StringName) -> void
func pause(run_id: String) -> void
func resume(run_id: String) -> void
func restore(continuation: SequenceContinuation) -> SequenceStartResult

signal sequence_started(run_id: String, sequence_id: StringName)
signal sequence_finished(run_id: String, result: SequenceResult)
signal sequence_failed(run_id: String, diagnostic: SequenceDiagnostic)

# Command-Spezifikation: darf den AST nicht verändern
func validate(instruction: SequenceInstruction,
              scope: SequenceValidationScope) -> Array[SequenceDiagnostic]
func start_command(context: SequenceContext,
                   instruction: SequenceInstruction) -> SequenceHandle
func declared_claims(instruction: SequenceInstruction) -> Array[StringName]

# Handle
func cancel(reason: StringName) -> void
func is_terminal() -> bool
func get_result() -> CommandResult
signal completed(result: CommandResult)
```

`SequenceStartResult`: `accepted`, `run_id`, `error_code`, `message`. Ein akzeptierter Start ist keine erfolgreiche Completion.

`CommandResult`: Status `SUCCESS`, `FAILED`, `CANCELLED`; `error_code`, `message`, typisierte `data`. `BattleResult.WIN` usw. sind fachliche Daten eines erfolgreichen Kampf-Commands; LOSE ist kein Infrastrukturfehler.

`SequenceResult`: `COMPLETED`, `ABORTED`, `FAILED`, dazu Script-Endecode und letzte sichere Grenze. `end code="escaped"` ist eine normale, bewusst geschriebene Completion; der Spielautor entscheidet, ob ein separater Story-Flag einen erfolgreichen Ausgang kennzeichnet.

Handle-Abschluss ist einmalig. Resultat wird gesetzt, **bevor** `completed` emittiert wird. Für sofort abgeschlossene Commands prüft der Runner nach `start_command` den terminalen Zustand; er wartet nicht blind auf ein bereits emittiertes Signal. Jeder Callback prüft Run-ID, Command-ID und Generation. Ein verspätetes Signal aus einem alten Level darf keinen neuen Command abschließen.

Neue Commands werden mit Name, Argumentschema, Claim-Schema, Persistenz-/Parallelitätsklasse und Versionsanforderung registriert. Doppelte Namen werden abgelehnt. Erweiterung bedeutet ein Command plus Adapterfähigkeit, keinen neuen Sonderfall im Parser.

## 7. Runner, Sperren und Lebenszyklus

### 7.1 Zustandsmaschine

```text
IDLE -> VALIDATING -> RUNNING <-> WAITING
                         |         |
                         +-> PAUSED+
                         |
                         +-> SUSPENDED_BATTLE -> RUNNING
                         +-> TRANSITIONING -> RUNNING
                         +-> RESTORING -> RUNNING
                         +-> COMPLETED / ABORTED / FAILED -> CLEANUP
```

Pause unterbricht Runner-Timer und Regieaktionen. Dialogeingaben werden deaktiviert, wenn das Spiel pausiert ist. Während eines Kampfes hat das Kampfsystem die Pausehoheit; der Runner ist suspendiert. `SceneTree.paused` nicht als alleinige Sequence-Steuerung verwenden.

Pro Tick gibt es ein Instruction-Budget, z.B. 100 sofortige Instructions, danach Yield bis zum nächsten Frame. Zusätzlich ein konfigurierbares Gesamtbudget seit dem letzten tatsächlichen Fortschritt, z.B. 10.000 Kontrollfluss-Instructions. Ein `goto`-Zyklus wird dadurch diagnostiziert statt das Spiel einzufrieren. Grenzen sind Runtime-Konfiguration, keine magischen Werte in jedem Command.

### 7.2 Besitz statt globales Entsperren

Der bestehende GameState-Lock-Zähler ist kompatibel zu verschachtelten Sperren, kann aber deren Besitzer nicht unterscheiden. Ziel ist ein Lease-Vertrag, z.B. `acquire_control(owner, domain)` / `release_control(lease)`, oder eine rückwärtskompatible Besitzerverwaltung um bestehende Locks.

- Runner erwirbt einen eigenen Gameplay-Input-Lease.
- Dialog und Transition erwerben eigene Leases; Cleanup löst nur eigene Leases.
- Sequence-Einstiege dürfen eine legitime Übergabe des aufrufenden Leases akzeptieren. Fremde modale Fenster und andere Besitzer bleiben sperrend.
- Beim Kampf wird der Sequence-Gameplay-Lease suspendiert bzw. an Combat übergeben; sonst könnte der globale Input-Lock auch die manuellen Kampfzüge verhindern. Interaktionen, Exploration, Party-Umsortierung und Levelausgänge bleiben während Combat gesperrt.
- Danach erwirbt die Sequence ihre Kontrolle zurück, **bevor** der Ergebniszweig startet.
- Niemals `_input_lock_count = 0` im Sequence-Code oder Sperren „bis null“ lösen.

Vor dem Einsatz prüfen, welche bestehenden Player-States und Menüs die globale Sperre auswerten. Ein Lease ist keine automatische Lösung: die Input-Domänen und Guard-Checks müssen konsistent angepasst werden.

### 7.3 Cleanup

Cleanup läuft bei `end`, Fehler, Cancellation, MainGame-Abbau und fehlgeschlagenem Resume genau einmal. Reihenfolge: neue Commands sperren; laufende Handles canceln; Listener/Timer trennen; nur eigene Dialoge/Bubbles schließen; Actor-Control zurückgeben; temporäre Actors entfernen; Audio-/Kamerakontrolle freigeben; eigene Input-Leases lösen; terminales Resultat veröffentlichen.

Persistente Weltänderungen werden bei einem Fehler nicht automatisch zurückgerollt. Ein Flag, ein Wissensgewinn oder ein abgeschlossener Kampf bleibt Teil der Welt, sofern nicht ausdrücklich ein früherer vollständiger Spielstand geladen wird. Diese Grenze muss Autoren und Debug-Werkzeugen sichtbar sein.

## 8. DSL-Version 1: Syntax und Parser

### 8.1 Lexikalische Regeln

- UTF-8; LF und CRLF werden akzeptiert. Optionales UTF-8-BOM wird am Dateianfang entfernt.
- Eine Instruction pro Zeile. Kein Semikolon und keine implizite Fortsetzung über mehrere Zeilen.
- `#` beginnt einen Kommentar außerhalb von Strings. Leerzeilen sind erlaubt.
- Commands und Schlüssel sind case-sensitive, klein geschrieben. Battle-Ergebnisse sind `WIN`, `LOSE`, `FLEE`, `ABORT`, `default`.
- Identifier: `[A-Za-z_][A-Za-z0-9_.-]*`. Zahlen: endliche Dezimalwerte; keine NaN/Infinity.
- Strings verwenden doppelte Anführungszeichen und unterstützen `\"`, `\\`, `\n`, `\t`. BBCode wird nur von ausdrücklich dafür geeigneten UI-Komponenten ausgewertet.
- Werte: String, Bool `true/false`, Integer, Float, Identifier oder erlaubter Query-Ausdruck. Keine Objekte, Lambdas, Arbiträr-Methoden, Array-Literale oder GDScript.
- Normalerweise `command positional key=value`. Unbekannte oder doppelte Schlüssel sind Fehler. Positionsparameter folgen dem jeweiligen Commandschema.
- Einrückung dient Lesbarkeit; Blockgrenzen sind explizit `endparallel`, `endbattle`, `endif`.
- Labeldefinition: `:label_name`; Sprung: `goto label_name`.
- `sequence ...` ist die erste nichtleere Zeile. `end` beendet einen Pfad; EOF ist kein implizites Erfolgsende.

### 8.2 Header

```text
sequence bandit_confrontation version=1 content_version=1 once=true map=monster_lair
```

`version` ist DSL-Version; `content_version` eine monotone Autorenrevision. `once=true` blockiert spätere Starts nach erfolgreichem `end`; ABORTED/FAILED verbrauchen die Sequence nicht. `map` ist die erforderliche Startkarte, im AssetCatalog auf einen Levelpfad aufgelöst. Verwendete Karten-/Asset-IDs müssen im Catalog existieren.

### 8.3 Kontrollfluss und Bedingungen

```text
if flag("abyss_gate_open") == true
    goto gate_open
elif party.has("shalka") and knowledge.knows("shalka", "abyss_warning")
    goto shalka_warning
else
    goto gate_closed
endif
```

Präzedenz: Klammern/Queries, `not`, Vergleiche, `and`, `or`. `and/or` werten kurzschließend von links nach rechts aus. Vergleiche: `==`, `!=`, `<`, `<=`, `>`, `>=`, letztere vier nur bei kompatiblen numerischen Typen. Keine implizite String-/Bool-Konvertierung.

Zugelassene Queries:

- `flag("id")`: in v1 Bool, fehlender registrierter Flag -> false.
- `party.has("character_id")`: aktive Mitgliedschaft, nicht bloß Existenz in CharacterRegistry.
- `knowledge.knows("character_id", "fact_id")`: Wissen dieser Figur.
- `quest.state("quest_id")`: definierter Queststatus als String.
- `local("name")`: lokaler Wert; fehlender Wert ist ein Fehler.
- `actor.exists("alias")`: gültiger LiveActor im aktuellen Kontext.

Fehlende oder unbekannte Quest-/Fact-/Character-IDs sind Validierungsfehler, kein falsches Queryresultat. Flags werden in einem Autorenkatalog registriert; eine registrierte, noch ungesetzte Bool-Flag ist zulässig. Actor-Aliase sind nur für Actor-Commands erlaubt; Knowledge-Queries verwenden Character-IDs, keine unklare Aliasauflösung.

Queries werden in einen typisierten AST geparst. WorldRules übernimmt vorhandene atomare Conditions. `and/or/not` werden vom sicheren ExpressionEvaluator zusammengesetzt. Party-Query benötigt eine neue passende WorldRules-Condition oder einen klaren StateAdapter-Vertrag. Nicht `Expression.execute()` mit beliebiger Projektumgebung verwenden.

### 8.4 Parserpipeline

1. Lexer mit Datei, Zeile und Spalte pro Token.
2. Header-/Command-/Blockparser erzeugt AST.
3. Expressionparser für die kleine Querygrammatik.
4. Typ- und Commandschemavalidierung.
5. Label-/Kontrollflussprüfung; Compile in flache Instructions und SourceMap.
6. Ressourcen-/Map-/Actor-Anforderungsprüfung.
7. Unveränderliches SequenceProgram in Catalog-Cache aufnehmen.

`parallel` ist kein allgemeiner Sprachblock: jede Zeile ist eine atomare Aktion. Keine Labels, Sprünge, Bedingungen, weiteren Parallelblöcke oder Barrieren darin. `battle` enthält ausschließlich Ergebniszuordnungen. `if` darf normalen Ablauf und verschachtelte `if` enthalten.

## 9. Blockieren, Parallelität und Claims

Ein normaler Command blockiert den Instruction Pointer bis zu seinem terminalen Handle. Auch scheinbar synchrone Effekte liefern einen sofort abgeschlossenen Handle. Ausnahmen sind ausdrücklich als „Startbestätigung“ definierte dauerhafte Effekte, etwa ein loopendes Musikbett; deren Wiedergabezeit blockiert nicht.

```text
parallel
    move player to=meeting_player speed=walk timeout=12
    move guide to=meeting_guide speed=walk timeout=12
    camera shot=meeting_wide duration=1.0 timeout=4
endparallel
```

Alle Kindaktionen starten nach gemeinsamer Vorprüfung in Quellreihenfolge im selben Frame. Der Join wartet auf **alle** Kinder. Keine frei laufenden Hintergrundjobs in v1. Sobald ein Kind fehlschlägt, werden Geschwister abgebrochen; der Block liefert einen Fehler. Bereits erfolgte Weltbewegungen bleiben bestehen.

Claim-Beispiele:

- `move`: `actor:<id>:locomotion`; `face` ebenfalls dieser Claim, wenn Bewegung die Orientierung bestimmt.
- `animate`: `actor:<id>:animation`; Bewegung reserviert zusätzlich den Locomotion-Animationskanal, falls dieser dieselbe Animation steuert.
- `bubble`: `actor:<id>:bubble`.
- `camera`: `camera:main`.
- `music`: `audio:music`; `sfx` besitzt einen separaten Voice-Handle.

Zwei Commands mit überlappenden exklusiven Claims sind vor Start Fehler. `move` und eine Ganzkörperanimation desselben Actors sind somit nicht gleichzeitig erlaubt; ein späterer ausdrücklich unabhängiger Upper-body-Kanal kann dies erweitern. Actor und Kamera können parallel laufen. Actor-übergreifende Bewegung ist zulässig.

Nicht parallelisierbar: Bind/Spawn/Despawn, vollständiger Dialog, Battle, Scene, Checkpoint, Effects/Flags, `end`, `goto` und Bedingungen. Sie sind Kontroll-/Persistenzbarrieren. `parallel on_error=label` ist optional; einzelne Kinder dürfen darin keine Sprungziele tragen. Der Runner behandelt den Blockfehler erst nach bestätigtem Cancel aller Kinder.

## 10. Marker, Actors, Bewegung und Animation

### 10.1 Benannte Marker

Ein neuer `SequenceMarker extends Marker3D` exportiert `marker_id`, `kind` und gegebenenfalls Arrival-/Radius-Einstellungen. Typen: `position`, `arrival`, `camera`, `look_at`, `zone`. Marker werden nur innerhalb des aktiven BaseLevel registriert. Doppelte IDs pro Level sind Fehler; dieselbe ID in verschiedenen Karten ist erlaubt.

Eine Zone besitzt einen benannten erreichbaren Zielmarker und optional Area3D/Shape. `move ... to=zone_id` läuft zum geprüften Anker und endet beim Eintritt in die Zone; ohne Zone gilt eine zentral definierte Distanz-/Höhentoleranz. Es werden keine Zufallspositionen im Collider gezogen.

Zu jeder Karte gehört ein Manifest mit Marker-IDs und Typen. Es erlaubt Prüfung von Sequence-Zielen vor dem Lauf, einschließlich Zielkarten eines Szenenwechsels. In Produktion Manifest aus Szenen generieren und Aktualität per Hash prüfen; bis dahin explizit gepflegte, im Debugvergleich kontrollierte Daten.

Markerauflösung liefert globale Transform3D-Werte über den Adapter. Der Parser akzeptiert keine `Vector3(...)`-Koordinaten. Interne Saved Placements dürfen weiterhin Positionen nutzen, da das bestehende Save-System diese braucht.

### 10.2 Actor-Auflösung und Lebensdauer

```text
actor guide bind=quest_giver_01
actor shalka bind=shalka
spawn scout prefab=abyss_scout at=scout_entry lifetime=sequence
despawn scout
```

LiveActorRegistry indiziert im aktiven Spielbaum gültige Playable-Nodes nach `character_id`. Sie meldet Doppeldeutigkeiten, statt den ersten Node auszuwählen. CharacterRegistry liefert Daten und Vorlagen; LiveActorRegistry liefert deren aktuelle Verkörperung.

`actor ... bind=...` bindet einen vorhandenen Actor. Fehlender Actor wird nicht implizit gespawnt. `spawn` nutzt ausschließlich einen erlaubten PrefabCatalog-Eintrag mit Character-Vorlage und Policy. Die Beispiel-ID `abyss_scout` ist neu anzulegen; sie ist keine vorhandene Ressource.

- `lifetime=sequence`: temporäre Figur wird bei Cleanup entfernt. Stabile Runtime-ID aus `run_id + alias`; beim erneuten Restore nicht doppelt erzeugen. Eigene Ressourcen und Registry-Einträge müssen kontrolliert freigegeben werden.
- `lifetime=world`: Descriptor in WorldState, autoritative Character-ID und Spawn-/Presence-Vertrag nötig. WorldSceneState allein stellt derzeit keine beliebigen dynamischen Actor-Szenen wieder her; ein Restore-Schritt wird ergänzt.
- Party-Actors werden unter EntityRoot kontrolliert, lokale NPCs unter LevelRoot. Weltpersistenz bedeutet nicht automatisch levelübergreifender Node.
- `despawn` entfernt Sequenz-eigene temporäre Actors. Bei `world` setzt es ein persistentes Presence-Ereignis und entfernt die Verkörperung. Gebundene fremde NPCs und Party-Mitglieder dürfen nicht versehentlich despawnt werden; dafür wäre ein eigener ausdrücklich registrierter Gameplay-Effekt nötig.
- Ein Required-Actor darf nicht nach Despawn weiter referenziert werden. Pfadabhängige Actor-Verfügbarkeit wird soweit möglich statisch, sonst zur Laufzeit geprüft.

Vor Ortswechsel werden lokale WeakRefs ungültig gemacht. Party-Bindings bleiben über IDs bestehen; lokale Actors werden auf der Zielkarte explizit neu gebunden oder aus WorldState wiederhergestellt. Laufende Sequence-Actors dürfen eine Transition nur passieren, wenn ihr Persistenzdescriptor am sicheren Übergabepunkt vollständig ist.

### 10.3 Bewegung

SequenceActorController übernimmt zeitweise Bewegung von der Actor-StateMachine/Follower-Logik. Es gibt **einen** Besitzer der horizontalen Bewegung. Input-Lock allein stoppt keine autonome Follower- oder NPC-Logik.

Der Move-Vertrag liefert `ARRIVED`, `UNREACHABLE`, `TIMEOUT`, `ACTOR_GONE`, `CANCELLED`. Geschwindigkeit `walk/run` wird in Actor-Profilen definiert, nicht im DSL in Metern pro Sekunde. Pfadplanung verwendet die tatsächliche Levelnavigation oder einen geprüften vorhandenen Ground-/Path-Service. Das Projekt ist 3D; kein neuer 2D-Movement-Pfad.

Movement tickt in der Physik, nutzt vorhandene Kollision/Gravitation, prüft Stagnation und Zielerreichung. Bei Timeout stoppt es den Actor und gibt einen Fehler zurück. Kein automatisches Teleportieren durch Wände. Autoren können einen Fehlerzweig schreiben; ein späterer `warp` wäre ein eigener ausdrücklich erlaubter Befehl.

Beim Kontrollbeginn Click-Move und Follow-Ziel pausieren; beim Ende keine veralteten Click-Move-Aufträge wiederbeleben. Follow-Enable und State werden gezielt wiederhergestellt. Während Battle besitzt Combat die Actors; keine Regie-Movement-Handles über diese Grenze hinweg.

### 10.4 Animation

`animate actor clip=...` spielt einen One-shot und wartet auf den korrelierten Clipabschluss. Semantische Clips werden im Actor-Profil auf SpriteFrames/AnimationPlayer/CharacterModelAnimator abgebildet. Fehlender Clip ist ein Validierungs- oder Runtimefehler.

Loopende Animationen benötigen `hold=<Sekunden>`; sonst werden sie abgelehnt, weil sie niemals fertig würden. Cancel trennt Signals und stellt einen zulässigen Idle-/Locomotion-State wieder her. `play_state()` allein gilt nicht als Abschlussvertrag; ein Adapter muss Dauer, Loop-Status und Unterbrechung sauber melden.

## 11. Textblasen und vollständige Gespräche

`bubble` ist eine kurze Äußerung über einem Actor: keine Antwortwahl, kein neuer Wissenszustand, kein vollständiger Gesprächskontext. Sie folgt dem Actor im Bildschirmraum, behandelt Offscreen-/Occlusion-Verhalten nach UI-Regeln und blockiert für ihre `duration`. Optional `key` für Übersetzung; `text` ist Fallback. Bei Actorverlust oder Cancel wird sie geschlossen.

`dialogue` delegiert vollständige Gespräche an DialogueSystem/ConversationUI/Dialogue Manager. Neue Ziel-API z.B. `start_sequence_dialogue(request_id, resource_id, title, participants, mode, caller_lease) -> handle`.

- `mode=single`: genau ein Titel samt Verzweigungen; dessen Abschluss schließt die UI und beendet den Handle.
- `mode=conversation`: bestehende Themenauswahl, bis der Spieler das Gespräch schließt. Der Runner wartet auf die ganze Sitzung.
- Completion unterscheidet `COMPLETED`, `USER_CLOSED`, `INTERRUPTED`, `FAILED`. `USER_CLOSED` ist in `single` eine Cancellation; Autoren können `on_cancel=label` angeben. `conversation` behandelt bewusstes Schließen als normale Completion.
- Dialogsitzung und Command werden über Request-ID korreliert; ein fremdes `dialogue_ended` genügt nicht.
- Sequence übernimmt keine Dialogoptionen und keine Addon-interne Zeilen-ID als Save-Cursor.
- Kampfstarts aus Sequence-Dialogen müssen entweder als Ergebnisabsicht an den Runner zurückgegeben oder für diesen Modus abgelehnt werden. Das bestehende `do start_encounter()` darf nicht unbemerkt einen Kampf am Battle-Continuation-Vertrag vorbei starten.
- Dialogmutationen laufen weiterhin über GameState/WorldRules; wiederholte irreversible Mutationen brauchen ebenfalls Event-/Idempotenzschutz.

Alle neuen UI-Flächen folgen `AGENTS.md` und `src/ui/theme/README.md`: NE_Theme, NEColors, NEDimensions, NETypography, Cuprum und vorhandene Standard-Controls. Modale Fenster verwenden SCRIM. Addon-Code und Beispiel-Theme werden nicht verändert.

## 12. Kamera und Audio

### Kamera

CameraSystem bleibt einziger Schreiber der aktiven Camera3D. Sequence fordert Shots über CameraAdapter an. Presets enthalten FOV, Blickziel, Übergang und Framing; die DSL nennt Preset-/Marker-IDs und Dauer.

Ziel ist ein Besitzerstack mit Priorität: Combat, aktiver Dialog, Sequence, Gameplay. Der Sequence-Camera-Lease wird bei Dialog/Kampf suspendiert und danach reaktiviert. Dialog-Shots laufen weiterhin über DialogueSystem. Cleanup kehrt zum jetzt gültigen Gameplaytarget zurück, nicht zu einem möglicherweise freigegebenen früheren Node.

`camera ... duration=1.0` wartet auf Ende des Übergangs, nicht auf eine zusätzliche Standzeit. Für eine gehaltene Einstellung folgt `wait`. CameraEventHub kann den Abschluss transportieren, benötigt aber Request-/Shot-ID, damit fremde Transition-Enden nicht den Command freigeben.

Optionaler PhantomCameraAdapter kann dieselben Requests später in PhantomCamera3D/Host und Prioritätswechsel übersetzen. Nekota-Kommandos bleiben identisch. Keine direkte Phantom-Node-Referenz im Context oder DSL.

### Audio

GameAudioSystem verwaltet Musikkanal, Crossfade und SFX-Voices. UIAudio bleibt für UI zuständig, FootstepPlayer für Schritte. Catalogs referenzieren AudioStream-Ressourcen und gültige Busnamen.

- `music play=... fade=...`: Completion nach Start/Crossfade, nicht nach Ende des Musikstücks. Musik loopt gemäß Assetprofil.
- `music stop=true fade=...`: Completion nach Fade-out.
- `sfx play=...`: normaler One-shot, Completion nach Wiedergabe. `at=actor_alias` ist räumlich; ohne `at` nicht räumlich.
- Loopende SFX sind in v1 nicht erlaubt. Keine Hintergrund-SFX-Handles über eine Barriere hinweg.
- Musik besitzt `scope=sequence` oder `scope=world`; sequence stellt den vorherigen zulässigen Musikzustand bei Cleanup wieder her, world aktualisiert die persistente Musikabsicht des Audio-Services.
- Beim Kampf-/Dialogübergang entscheidet das Audio-System über Ducking und Priorität. Sequence verändert keine fremden Buslautstärken dauerhaft.
- Musikposition wird in v1 nicht samplegenau gespeichert. Restore startet den gespeicherten Welttrack neu; das wird als bewusste Grenze dokumentiert.

## 13. Szenenwechsel

```text
scene map=monster_lair arrival=sequence_arrival timeout=15 on_error=transition_failed
```

SceneAdapter ruft einen neuen öffentlichen LevelManager-Vertrag auf, z.B. `transition_for_sequence(request_id, map_path, arrival_id, caller_lease) -> handle`. Bestehende Area-Übergänge verwenden möglichst denselben internen Transitionkern.

1. Keine aktiven Move-/Animation-/SFX-/Dialog-Handles; Parallelblock bereits gejoint.
2. Zielressource, BaseLevel-Typ und Arrival-Marker vor Entladen prüfen.
3. Vor-Transition-Continuation im alten vollständigen WorldState committen.
4. Fade-out unter kontrollierter Lease-Übergabe; keine ungeschützte Gameplayphase.
5. WorldSceneState erfassen, alte lokale Registries invalidieren, Level tauschen.
6. Party am Arrival platzieren; WorldState/PersistentActors wiederherstellen.
7. Marker-, Actor-, Kamera- und Physikbereitschaft bestätigen. `level_loaded` allein ist keine allgemeine Readiness-Barriere.
8. Ziel-Continuation atomar committen; Fade-in beenden, dann nächster Command.

Ein Transition-State enthält `from_map`, `to_map`, `arrival`, `stage` und nächste stabile Resume-Grenze. Crash vor dem Zielcommit lädt den vollständigen Vor-Transition-Snapshot; danach den Ziel-Snapshot. Keine Mischung aus alter Welt und Ziel-Cursor.

Bei Fehler bleibt die alte Welt erhalten oder wird aus dem vorbereiteten Snapshot konsistent wiederhergestellt. Ein Fehlerlabel läuft nur in einer bereiten Welt. Wenn Recovery selbst fehlschlägt, endet die Sequence kontrolliert und der vorhandene Lade-/Menüpfad zeigt den Fehler; kein `goto` in ein entladenes Level.

## 14. Bedingungen, Flags, Wissen, Party und Quests

DSL-V1-Flags sind Bool-Werte. Obwohl GameState beliebige Variants entgegennehmen kann, validiert WorldRules derzeit Bool-Conditions; breitere Typen werden erst mit einem expliziten Schema ergänzt.

```text
set flag="abyss_warning_seen" value=true id=warning_seen
let route value="cautious"
effect learn_fact character="shalka" fact="abyss_warning" id=learn_warning
effect start_quest quest="bandit" id=accept_bandit
```

`let` verändert nur lokale Werte. `set` und `effect` sind persistente WorldRules-Effekte. Der Compiler prüft registrierte Flag-/Fact-/Quest-IDs. Eine Fact-Definition gehört in den World-/Content-Setup, nicht in eine beiläufige Dialogzeile.

Zulässige Effekte in v1:

- `learn_fact`, `forget_fact`: vorhandene Wissensdomäne.
- `start_quest`: zulässiger Questübergang; anfangs nur `bandit`.
- `complete_quest`: gültige Vorbedingungen plus Character-ID und Completion-Flag gemäß QuestProgress/WorldRules; nicht beliebiger Statussetzer.
- `reward_encounter`: neu zu ergänzender atomarer Gameplay-Effekt; nur für korreliertes WIN und passenden Encounter-Metadateneintrag.

Jeder persistente Effekt braucht eine im Script eindeutige `id`. Schlüssel: `(run_id, effect_id)`. Die WorldRules-Transaktion umfasst Weltänderung, Event und angewendete Effekt-ID; bei Fehler wird nichts davon übernommen. „Erst Reward vergeben, dann Flag schreiben“ ist unzulässig.

Bei `once=true` sind eventuelle runübergreifende Einmalbelohnungen zusätzlich über einen Story-/Encounter-Eventschlüssel geschützt. Ein neu gestarteter Run hat eine neue UUID und darf keine bereits abgeschlossene Quest erneut belohnen.

## 15. Kampfstart und Fortsetzung

### 15.1 DSL-Vertrag

```text
battle encounter=bandit_ambush attacker=player target=bandit timeout=15
    WIN -> victory
    LOSE -> defeat
    FLEE -> escaped
    ABORT -> interrupted
    default -> battle_failsafe
endbattle
```

Alle vier Ergebnisse und `default` sind in v1 verpflichtend. Doppelte Ergebnisse und fehlende Labels sind Compilefehler. Es gibt **kein** implizites Fall-through nach dem Block. `timeout` begrenzt nur Kampfstart und Ergebnis-/Restore-Übergabe, nicht die Spiellänge eines aktiven Kampfes.

`attacker/target` referenzieren Actor-Aliase. CombatParticipantResolver und RelationshipService bleiben für Seiten/Bystander zuständig. `encounter` referenziert Metadaten/Policy für diesen gescripteten Kampf; es erzeugt keine neue statische Gegnerliste aus EncounterData. Policies können zusätzliche Startbedingungen festlegen, müssen aber in CombatManager umgesetzt werden.

### 15.2 Normalisiertes BattleResult

```text
request_id, session_id, run_id
result: WIN | LOSE | FLEE | ABORT | UNKNOWN
controlled_character_ids
controlled_side
defeated_ids, fled_ids, surviving_ids
reason
world_commit_id
```

Resultat ist aus Sicht der beim Start festgehaltenen kontrollierten Party zu verstehen, nicht aus Sicht „attacker ist immer Spieler“. Wenn die Beziehungssysteme diese Figuren in widersprüchliche Seiten einordnen, muss die Encounter-Policy den Start ablehnen oder eine explizite kontrollierte Gruppe definieren.

- `WIN`: festgelegtes Gegnerziel ist durch Niederlage erfüllt und die kontrollierte Gruppe nicht besiegt. Gegnerflucht allein erfüllt das Ziel nicht.
- `LOSE`: die kontrollierte Gruppe ist vollständig besiegt; tote Einzelmitglieder bei sonst fortgesetztem Kampf ergeben noch kein terminales LOSE.
- `FLEE`: die kontrollierte Gruppe hat erfolgreich den Encounter verlassen, mindestens ein kontrolliertes Mitglied ist entkommen, niemand aus der Gruppe kämpft weiter. Ein fehlgeschlagener Fluchtwurf oder ein abgebrochener Fluchtweg ist kein terminales FLEE.
- `ABORT`: regulärer technischer/inhaltlicher Abbruch, Zielverlust ohne Sieg, Gegnerflucht ohne erfülltes Ziel oder beidseitiger Ausfall nach definierter Policy. Ursache steht in `reason`.
- `UNKNOWN`: beschädigte/unbekannte Payload oder nicht unterstütztes Resultat; führt zu `default` und Diagnose.

Für gleichzeitig terminale Zustände gilt die v1-Policy: beidseitiger Ausfall -> ABORT; sonst vollständige kontrollierte Niederlage -> LOSE; sonst kontrollierte Flucht -> FLEE; sonst bestätigtes Gegnerziel -> WIN; sonst ABORT. CombatManager erzeugt genau einen Abschluss nach finaler Prüfung.

Bei erzwungenem MainGame-Abbau kann der Runner nicht mehr im alten Level weiterspringen. Dann wird ABORT als Recovery-/History-Status gespeichert, und Cleanup ersetzt unmittelbare Branch-Ausführung.

### 15.3 Übergabeprotokoll

1. Alle Regieaktionen joinen; eigene Gespräche schließen; Actor-/Kamera-/Audio-Leases suspendieren.
2. Sicheren Vor-Kampf-Snapshot samt `PREPARED`-Continuation und eindeutiger Request-ID persistieren. Bei Schreibfehler startet kein Kampf.
3. Listener/Handle vor Start registrieren; `CombatManager.start_sequence_encounter(request)` muss entweder akzeptieren und Session-ID liefern oder ausdrücklich ablehnen. Das heutige `trigger_attack()` ohne Resultat reicht dafür nicht.
4. Sequence-Input-Lease für Kampfeingaben übergeben; Runner bleibt `SUSPENDED_BATTLE`.
5. Combat normalisiert Ergebnis, beendet Teilnehmerzustände und committed Kampf-Weltänderungen.
6. BattleResult und vollständige Post-Kampf-Welt gemeinsam als `RESULT_READY` speichern. Bei Schreibfehler Ergebnis in Memory halten, Runner suspendiert lassen und kontrollierten Retry/Recovery anbieten; keine Erfolgseffekte ausführen.
7. Weltreadiness prüfen, Regiekontrolle zurückholen, Ergebnislabel auswählen und Continuation als fortgesetzt markieren.
8. Erfolgs-/Reward-Effekte laufen nur im WIN-Zweig und idempotent. LOSE/FLEE/ABORT/default erhalten eigene sichere Enden.

Globale `combat_ended`-Signale werden nach Session-ID gefiltert. Doppelte oder verspätete Events ändern weder Cursor noch Rewards. Events eines anderen Kampfes werden ignoriert und im Debugtrace sichtbar.

### 15.4 Failsafes und Grenzen

- **LOSE:** Spielautor kann einen kontrollierten Fail-forward nach Design oder die Wiederherstellung des Vor-Kampf-Snapshots wählen. V1-Standard: kein automatisches Wiederbeleben; Sequence endet mit `defeat`, danach vorhandener Recovery-/Game-over-Einstieg. Da dieser laut CombatManager-Kommentar noch nicht vollständig angebunden ist, muss Phase 3 einen minimalen sicheren Recovery-Vertrag ergänzen.
- **FLEE:** kein Siegflag, kein Encounter-Reward. Fluchtplatzierungen respektieren; nicht automatisch zurück vor den Gegner teleportieren. Das Fluchtlabel endet oder führt in eine dazu passende Nachszene.
- **ABORT/default:** kontrollierte Beendigung ohne Erfolgseffekte, Diagnose, eigene Sperren lösen. Bei ungültiger Welt zurück zum geprüften Vor-Kampf-Snapshot/Recovery-Menü.
- **Startablehnung:** geht als `ABORT` mit `reason=start_rejected` in den ABORT-Zweig; ein gültiger prebattle Snapshot bleibt verfügbar.
- **Crash mitten im Kampf:** V1 speichert keinen aktiven Kampf. Laden des letzten PREPARED-Snapshots startet den Encounter erneut aus dem vollständigen Vor-Kampf-Zustand. Ein bereits gespeichertes RESULT_READY spielt den Kampf nicht erneut.
- **Retry:** eigener neuer Battle-Request bei unveränderter Run-ID. Effekt-IDs werden dabei nicht neu vergeben. Ein Retry ist eine bewusste Autoren-/Recoveryaktion, keine Endlosschleife.

## 16. Checkpoints und Savegame-Verhalten

### 16.1 Sichere Grenze

```text
checkpoint before_ambush resume=ambush_start save=autosave
:ambush_start
```

Der Checkpoint speichert den vollständigen konsistenten Weltzustand **nach** allen vorherigen Commands und den Cursor zum angegebenen Label. Das Label muss außerhalb aller Blöcke liegen. Es markiert den direkt folgenden Resume-Abschnitt; das Script darf keine dazwischenliegenden notwendigen Setup-Commands überspringen.

Vor einem Checkpoint: keine laufenden parallelen Kinder, Bewegung, One-shots, Dialoge, Transitions oder Kämpfe. Musikloop darf als persistente Absicht existieren. Actor-Kontrolle wird kurz in einen snapshotfähigen stabilen Zustand gebracht. Temporäre Actors werden entweder vollständig beschrieben oder vor dem Checkpoint entfernt; ungeklärte Actor-Lebensdauer verbietet Speichern.

`save=memory` setzt nur einen Laufzeit-Snapshot für Debug/Recovery derselben Sitzung. `save=autosave` schreibt über den SaveAdapter ein echtes Savegame. Diese Bedeutungen dürfen im UI nicht verwechselt werden.

### 16.2 Persistenzschema

WorldState erhält z.B. `sequence_state` mit Schema-Version und folgenden Feldern:

```json
{
  "schema_version": 1,
  "completed": {"arrival": {"content_version": 1, "end_code": "arrived"}},
  "active": {
    "run_id": "<uuid>",
    "sequence_id": "bandit_confrontation",
    "dsl_version": 1,
    "content_version": 1,
    "content_hash": "<sha256>",
    "checkpoint_id": "before_ambush",
    "resume_label": "ambush_start",
    "location_id": "monster_lair",
    "locals": {},
    "actor_bindings": {"player": "dannerman", "bandit": "lair_bandit_01"},
    "actor_descriptors": [],
    "applied_effect_ids": [],
    "phase": "CHECKPOINT_READY",
    "battle": null
  }
}
```

Dies ist ein schematisches Beispiel, kein derzeitiger Save-Payload. WorldValueCodec übernimmt die eigentliche typisierte Kodierung. `completed` ist unabhängig von „Encounter gewonnen“; Storyflags modellieren Ausgänge separat. Für wiederholbare Sequences begrenzte History statt unbegrenzt wachsender Logs vorsehen.

WorldSaveStore-Version erhöhen (bei unverändertem Ausgangsstand 8 -> 9), Reader/Writer/clear()/WorldLoader gemeinsam ergänzen. Alte Spielstände erhalten leere Sequence-Daten. Erforderliche Felder, Typen, IDs, Hashes und Maximalgrößen strikt prüfen; unbekannte Zukunftsversion ablehnen. Bestehende Migrationen und Quest-/Partyvalidierung bleiben erhalten.

### 16.3 Atomare Commit-Grenzen

Weltzustand und Sequence-Continuation gehören in **dieselbe** Save-Datei. Zwei unabhängig geschriebene Dateien können Rewards und Cursor auseinanderlaufen lassen. Den vorhandenen `.tmp`-Write-/Read-/Rename-Weg erweitern, nicht ein zweites Speichersystem aufbauen.

Ein Checkpoint-Save darf die eigene Sequence-Sperre ausdrücklich berücksichtigen, ohne fremde Locks zu ignorieren. `save_world()` wird nicht über Reset des Zählers umgangen. SaveAdapter benötigt eine geprüfte interne Snapshot-API mit Besitzerrecht und Ready-Prüfung.

Manuelles Speichern während anderer Sequence-Abschnitte bleibt gesperrt und meldet „Speichern nach dieser Sequenz verfügbar“. Nachträglich kann der Menü-Save-Button an einem expliziten safe point angeboten werden. Ein freies Gameplay-Save nach Sequence-Ende enthält completed/history und sämtliche Storyeffekte.

### 16.4 Resume-Reihenfolge

1. SaveStore liest und validiert einen separaten WorldState-Kandidaten.
2. WorldLoader baut MainGame, Party und aktives Level auf; vorhandene Rollbackfähigkeit erhalten.
3. Scene-/Actor-/Marker-/Audio-Services melden readiness; SequenceManager startet nicht vor `_is_ready`/abgeschlossener Installation.
4. Program-ID, Version, Hash, Resume-Label und Bindings prüfen.
5. Actors/Präsentationsabsichten rekonstruieren; Leases **neu** erwerben, keine alten Lock-Zähler laden.
6. CHECKPOINT_READY -> Label; PREPARED -> neuer Start aus Vor-Kampf-Snapshot; RESULT_READY -> Ergebnislabel ohne Kampfneustart.
7. Danach erst Trigger freigeben. Autorun-/Area-Trigger dürfen keinen zweiten Run während Restore starten.

Bei Hashänderung nicht den alten Instruction Pointer weiterbenutzen. V1 verlangt exakt passende Content-Version/Hash oder eine ausdrücklich geprüfte Migration von stabilem Checkpoint/Label. Ohne Migration: Sequence-Recovery erklären, sicher beenden bzw. kompatiblen Spielstand anbieten; bestehende Welt nicht still neu starten. Bereits applied Effekte bleiben erhalten.

## 17. Befehlsreferenz DSL v1

Alle Befehle verwenden ausschließlich Catalog-/Actor-IDs. „Blockiert“ beschreibt die Handle-Completion, nicht eine globale Pause des Spiels. Folgende Referenz ist der vollständige v1-Vertrag.

### Metadaten und Kontrollfluss

- `sequence <id> version=1 content_version=<int> once=<bool> map=<id>`: einmaliger Header, keine Runtimeaktion.
- `:<label>`: eindeutiges Label, keine Parameter.
- `goto <label>`: unmittelbarer Sprung; nicht innerhalb `parallel/battle`.
- `if <expr>` / `elif <expr>` / `else` / `endif`: Branching gemäß Querygrammatik.
- `let <name> value=<scalar>`: lokalen typisierten Wert setzen; sofortig.
- `wait <seconds>`: nichtnegative Zeit in Sequence-Zeit; pausierbar, parallel zulässig. Null yieldet mindestens einen Frame, um Busyloops zu vermeiden.
- `parallel [on_error=<label>]` / `endparallel`: all-Join, keine Schachtelung.
- `end [code="<string>"]`: normaler Abschluss, Cleanup; Standardcode `completed`.
- `abort [reason="<string>"]`: gewollter ABORTED-Abschluss, kein once-Completion-Eintrag, Cleanup.

### Actors und Präsentation

- `actor <alias> bind=<character_id>`: LiveActor binden; sofortig; keine Parallelität.
- `spawn <alias> prefab=<id> at=<marker> lifetime=sequence|world [on_error=<label>]`: wartet auf Registration/Readiness, nicht parallel.
- `despawn <alias>`: wartet auf Abmeldung; Besitzregeln prüfen, nicht parallel.
- `move <alias> to=<marker> speed=walk|run timeout=<seconds> [on_error=<label>]`: wartet auf Ankunft; Standard speed `walk`, Standard timeout 15; parallel zulässig.
- `face <alias> toward=<alias> [timeout=<seconds>]`: wartet auf Orientierung; Standardtimeout 3; parallel zulässig unter Claims. Ziel ist Actor, kein Marker; Markerblick wäre eine spätere eindeutig benannte Erweiterung.
- `animate <alias> clip=<id> [hold=<seconds>] [timeout=<seconds>] [on_error=<label>]`: wartet auf One-shot-Ende bzw. hold; Standardtimeout 10, Loop nur mit hold; parallel zulässig.
- `bubble <alias> text="..." [key="translation.key"] duration=<seconds>`: Dauer > 0, wartet bis geschlossen; parallel zulässig. Key bevorzugt, Text Fallback.
- `dialogue resource=<id> title=<id> speaker=<alias> mode=single|conversation [on_cancel=<label>] [on_error=<label>]`: blockiert Sitzung; Standardmode single; nicht parallel. Kein allgemeiner Zeitlimit für Spielerentscheidungen, aber Readiness-/Cleanup-Watchdog.

### Kamera und Audio

- `camera shot=<preset_id> [subject=<alias>] [look_at=<alias>] duration=<seconds> [timeout=<seconds>] [on_error=<label>]`: wartet auf Transition; Preset kann Camera-Marker referenzieren; timeout standardmäßig duration + 3; parallel zulässig.
- `camera restore=true duration=<seconds> [timeout=<seconds>]`: kehrt zur aktuell zulässigen Basiskontrolle zurück; parallel zulässig, sofern kein Camera-Claim-Konflikt.
- `music play=<audio_id> fade=<seconds> scope=sequence|world`: wartet auf Crossfade, nicht Wiedergabeende; parallel zulässig, timeout intern fade + 3.
- `music stop=true fade=<seconds> scope=sequence|world`: wartet auf Fade-out; play und stop schließen einander aus.
- `sfx play=<audio_id> [at=<alias>] [timeout=<seconds>] [on_error=<label>]`: wartet auf One-shot; parallel zulässig, timeout Standard Assetdauer + 3. Assets ohne bekannte endliche Dauer benötigen expliziten timeout.

### Welt, Kampf und Persistenz

- `set flag="<id>" value=<bool> id=<effect_id>`: atomarer Bool-Effekt und Idempotenzmarker; sofortiger Abschluss, nicht parallel.
- `effect learn_fact|forget_fact character="<id>" fact="<id>" id=<effect_id>`: WorldRules-Effekt; nicht parallel.
- `effect start_quest quest="<id>" id=<effect_id>`: zulässiger Queststart; nicht parallel.
- `effect complete_quest quest="<id>" character="<id>" flag="<id>" id=<effect_id>`: geprüfter Abschluss nach WorldRules; nicht parallel.
- `effect reward_encounter encounter=<id> recipient=<alias> id=<effect_id>`: atomare Encounterbelohnung, erfordert passenden WIN im Context und Reward-Policy; nicht parallel.
- `checkpoint <id> resume=<label> save=memory|autosave`: Safe-point-Barriere; Schreibfehler ist Fehler, kein stiller Erfolg.
- `scene map=<id> arrival=<marker> [timeout=<seconds>] [on_error=<label>]`: Transition-Barriere; Standardtimeout 15; alte lokale Bindings invalidieren.
- `battle encounter=<id> attacker=<alias> target=<alias> [timeout=<seconds>]` plus alle Ergebniszeilen und `endbattle`: persistente Kampfbarriere; Standard Start-/Resume-Timeout 15.

`on_error` gilt nur für Commands, deren Schema es aufführt. Ohne Handler endet ein Runtimefehler als FAILED. Wiederholte automatische Fehlerbehandlung hat ein Budget; ein fehlerhaftes Fehlerlabel darf keine unbegrenzte Retrieschleife erzeugen. `on_cancel` gibt es nur beim Dialog; Manager-Cancellation beendet den gesamten Run unabhängig von Autorenlabels.

## 18. Vollständige DSL-Beispiele

Die Syntax ist normativ für die geplante v1-Implementierung. Ressourcen wie `arrival_intro`, `bandit_ambush`, Camera-Presets, Fact `abyss_warning`, Audio-IDs und SequenceMarker müssen bei der Umsetzung angelegt und im Catalog registriert werden. Sie sind illustrative Necota-Inhalte; bestehende Character-IDs werden ausdrücklich verwendet.

### Beispiel A: Ankunft, Bewegung, Textblase und Dialog

Voraussetzungen: Startkarte `chapter1_outskirts` zeigt auf `Level1Ep1.tscn`; quest_giver_01 ist dort ein LiveActor. Marker `meeting_player` und `meeting_guide`, Preset `meeting_wide`, Dialogresource `arrival_intro` mit Titel `start` existieren.

```text
sequence arrival version=1 content_version=1 once=true map=chapter1_outskirts

actor guide bind=quest_giver_01
music play=outskirts_ambience fade=1.0 scope=world

parallel on_error=staging_failed
    move player to=meeting_player speed=walk timeout=12
    move guide to=meeting_guide speed=walk timeout=12
    camera shot=meeting_wide duration=1.0 timeout=4
endparallel

face guide toward=player
bubble guide text="Ihr seid spät dran." key="arrival.guide_late" duration=2.0
dialogue resource=arrival_intro title=start speaker=guide mode=single on_cancel=conversation_closed
set flag="arrival_seen" value=true id=mark_arrival
camera restore=true duration=0.5
end code="arrived"

:conversation_closed
camera restore=true duration=0.5
abort reason="Gespräch vorzeitig geschlossen"

:staging_failed
abort reason="Treffpunkt nicht erreichbar"
```

`arrival_intro` ist eine neu anzulegende `.dialogue`-Resource; sie enthält die eigentlichen Zeilen/Antworten. Der Guide sagt seine kurze Bemerkung per Bubble, danach übernimmt ConversationUI das vollständige Gespräch.

### Beispiel B: Kampf mit sämtlichen Ausgängen

Voraussetzungen: `monster_lair` zeigt auf die bestehende MonsterLair-Level1-Szene; `lair_bandit_01` existiert. Encountercatalog `bandit_ambush` definiert Ziel-/Rewardpolicy. Checkpoint-Resume und Recovery-Vertrag sind implementiert.

```text
sequence bandit_confrontation version=1 content_version=1 once=true map=monster_lair

actor bandit bind=lair_bandit_01
bubble bandit text="Keinen Schritt weiter!" key="bandit.stop" duration=1.5
checkpoint before_ambush resume=ambush_start save=autosave

:ambush_start
battle encounter=bandit_ambush attacker=player target=bandit timeout=15
    WIN -> victory
    LOSE -> defeat
    FLEE -> escaped
    ABORT -> interrupted
    default -> battle_failsafe
endbattle

:victory
set flag="sequence_bandit_won" value=true id=mark_win
effect reward_encounter encounter=bandit_ambush recipient=player id=ambush_reward
bubble player text="Der Weg ist frei." key="bandit.won" duration=2.0
checkpoint after_victory resume=finish_victory save=autosave
:finish_victory
end code="victory"

:defeat
end code="defeat"

:escaped
set flag="sequence_bandit_escaped" value=true id=mark_escape
bubble player text="Wir müssen einen anderen Weg finden." key="bandit.escaped" duration=2.0
end code="escaped"

:interrupted
abort reason="Begegnung unterbrochen; kein Sieg und keine Belohnung"

:battle_failsafe
abort reason="Unbekanntes Kampfergebnis; Recovery erforderlich"
```

Der LOSE-Pfad startet nach Cleanup den vom BattleAdapter vorbereiteten Recovery-/Game-over-Vertrag. Er benötigt keine lebende Figur für eine Bubble und vergibt keinen Reward. Nur WIN verwendet den Reward-Effekt. Bestehende NPC-Defeat-Flags/Eventlogik bleiben im Kampfsystem.

### Beispiel C: Wissen, Party und Queststatus

Voraussetzungen: shalka ist aktiv, Fact `abyss_warning` ist in WorldState definiert; Dialogresources/presets existieren. Die vorhandene `bandit`-Quest wird verwendet, keine erfundene Questpersistenz.

```text
sequence abyss_warning version=1 content_version=1 once=false map=chapter1_outskirts

if flag("abyss_warning_seen") == true
    goto already_seen
endif

if party.has("shalka") and knowledge.knows("shalka", "abyss_warning")
    goto informed_companion
elif quest.state("bandit") == "ready"
    goto quest_ready
else
    goto unknown_path
endif

:informed_companion
actor companion bind=shalka
camera shot=companion_close subject=companion look_at=player duration=0.7
dialogue resource=abyss_warning_dialogue title=knows_warning speaker=companion mode=single on_cancel=cancelled
set flag="abyss_warning_seen" value=true id=warning_seen
goto finish

:quest_ready
bubble player text="Zuerst berichten wir vom Banditen." key="abyss.quest_ready" duration=2.0
goto finish

:unknown_path
bubble player text="Wir wissen noch zu wenig über diesen Ort." key="abyss.unknown" duration=2.0
goto finish

:already_seen
end code="already_seen"

:finish
camera restore=true duration=0.4
end code="warning_finished"

:cancelled
abort reason="Warnungsgespräch geschlossen"
```

### Beispiel D: Spawn, Animation, Wissen und Ortswechsel

Voraussetzungen: neues temporäres Prefab `abyss_scout`, Marker `scout_entry`, `scout_meeting`, `player_meeting`, One-shot `point`, SFX `stone_door`, Dialog `scout_report`, Fact und Flag registriert. Zielkarte besitzt Arrival `sequence_arrival` und NPC `lair_bandit_01`.

```text
sequence scout_report version=1 content_version=1 once=true map=chapter1_outskirts

spawn scout prefab=abyss_scout at=scout_entry lifetime=sequence on_error=failed
parallel on_error=failed
    move scout to=scout_meeting speed=run timeout=10
    move player to=player_meeting speed=walk timeout=10
endparallel
face scout toward=player
animate scout clip=point timeout=5 on_error=failed
dialogue resource=scout_report title=start speaker=scout mode=single on_cancel=cancelled on_error=failed
effect learn_fact character="dannerman" fact="abyss_warning" id=learn_route
set flag="scout_report_received" value=true id=report_received
despawn scout
checkpoint before_lair resume=enter_lair save=autosave

:enter_lair
sfx play=stone_door timeout=5 on_error=failed
scene map=monster_lair arrival=sequence_arrival timeout=15 on_error=transition_failed
actor bandit bind=lair_bandit_01
bubble bandit text="Ihr hättet draußen bleiben sollen." key="lair.arrival" duration=2.0
checkpoint inside_lair resume=finish save=autosave
:finish
end code="entered_lair"

:transition_failed
abort reason="Zielkarte nicht bereit; bisherige Welt bleibt erhalten"

:cancelled
abort reason="Bericht geschlossen"

:failed
abort reason="Bericht konnte nicht inszeniert werden"
```

Der Wissenserwerb ist hier absichtlich an `dannerman` gebunden. Sollte die erzählerische Absicht stattdessen „aktueller Sprecher weiß es“ sein, muss die Contentdefinition eine geprüfte Character-ID übergeben; nicht Wissen aller Partymitglieder implizit erweitern. Temporäre Figuren sind vor dem Checkpoint entfernt, wodurch der Resume-Vertrag einfach bleibt.

## 19. Verwendung im Projekt

### Autorenworkflow

1. Sequence-ID und Storyausgänge festlegen; einmalig oder wiederholbar entscheiden.
2. Benötigte Figuren, Dialogtitel, Maps, Marker, Kamera-/Audio-IDs und Flags/Facts registrieren.
3. SequenceMarker im Level anlegen; Manifest aktualisieren.
4. `.sequence` schreiben, vollständigen Validator ausführen und Diagnosefehler beheben.
5. SequenceCatalog-Eintrag erzeugen.
6. Area3D-/Interaktions-Trigger oder Questevent mit Sequence-ID versehen.
7. Im Debug-Menü mit verschiedenen Party-/Quest-/Wissenszuständen starten.
8. Alle Kampfresultate, Cancellation und jeden Checkpoint-Resume testen.

Ein neuer SequenceTrigger ruft nur `SequenceManager.start()` auf. Er manipuliert weder Flags noch Kamera selbst. Beim `BUSY`-Resultat bleibt er wieder auslösbar; er speichert keine Completion auf Eintritt in eine Area. Debounce gilt bis zum Startresultat und verhindert doppelte Physics-Signale. `once`/History entscheidet zentral über Wiederholbarkeit.

Beispiel für späteren Projektcode, **keine aktuelle API**:

```gdscript
var started := sequence_manager.start(&"bandit_confrontation", {}, &"lair_entry")
if not started.accepted:
    # BUSY später erneut auslösbar; Contentfehler im Debuglog anzeigen.
    return
```

### Codex-Implementierungsregeln

- Vor Änderungen AGENTS.md, betroffene Architecture-Dokumente und aktuelle APIs lesen; Befunde dieses Dokuments nachprüfen.
- Ersten Slice in MainGame integrieren, nicht neues Framework neben dem vorhandenen Spiel bauen.
- Neue Ziel-APIs von bestehenden unterscheiden; keine privaten `_...`-Methoden als stabile öffentliche Verträge verwenden.
- Keine Änderungen im Drittanbieter-Addon für Sequence-Funktionen.
- Kein Godot-/Dialogue-Manager-Upgrade als Voraussetzung einführen. Vorhandene 4.7-Projektkonfiguration und 3.10.5-Addon zunächst beibehalten; installierte Engineversion zusätzlich prüfen.
- Save-/WorldRules-Änderungen nur zusammen mit Reader, Migration und aussagekräftigen Regressionen.
- Nicht voraussetzen, dass EncounterData Gegner spawnt oder derzeit bereits Rewards verteilt.
- UI-Designsystem für Bubbles, Debugger und Recovery beachten.
- Spielsystemtests verwenden; kein zweites Testframework installieren, wenn die vorhandenen Testszene-/Exitcode-Konventionen ausreichen.
- Nach jeder Phase lauffähige Demo, dokumentierte Grenzen und überprüfbare Abnahmekriterien liefern.

## 20. Fehlerbehandlung und Validierung

### 20.1 Diagnostik

Jede Diagnose enthält `severity`, `code`, `sequence_id`, Datei, Zeile, Spalte, Command-ID, Actor-/Asset-ID und verständliche Erklärung. Runtime zusätzlich `run_id`, Levelgeneration und letzter sicherer Checkpoint.

Beispiel:

```text
ERROR SEQ_MARKER_MISSING
bandit.sequence:14:20 · run=<uuid> · map=monster_lair
move player: Marker 'meeting_player' ist auf dieser Karte nicht definiert.
```

Fehlerklassen: Syntax, unbekannter Command/Parameter, Typfehler, ungültige Expression, fehlende Ressource/ID, Actor-/Markerverlust, Claimkonflikt, Startablehnung, Timeout, Savefehler, Versionskonflikt und Adapterausfall.

### 20.2 Statische Prüfungen

- Header/Version/ID eindeutig; Command- und Wertschemas exakt.
- Blocks balanciert; Labels eindeutig und alle Sprungziele existent.
- Jeder erreichbare Kontrollflusspfad endet bewusst oder wird als Schleife markiert; unerreichbare Labels sind Warnungen.
- Battle hat alle Ergebniszweige und `default`, keine Labels innerhalb des Blocks.
- Parallelität/Claims geprüft; keine persistente Barriere im Parallelblock.
- Aliase bindbar und auf jedem relevanten Pfad definiert; kein Required-Actor nach Despawn.
- Maptyp, Arrival-, Zielmarker- und Camera-Preset-Anforderungen passen; Mapzustand nach Scene im Kontrollfluss berücksichtigen.
- Dialogresource/Titel, Clip, Audio, Flag, Fact und Quest existieren.
- Persistente Effekt-IDs sind eindeutig; Checkpoint-/Resume-Labels stabil.
- Retry-/Goto-Zyklen, nichtfinite Dauern, negative Zeitwerte, unbounded loopende Clips und SFX ablehnen.

Wo Flowanalyse LiveActor-Verfügbarkeit nicht beweisen kann, erfolgt eine Warnung plus verpflichtender Start-/Runtimecheck. Kein Validator-Versprechen, das eine dynamische Welt nicht erfüllen kann.

### 20.3 Laufzeitregeln

Vor Start benötigte Services und Startkarte prüfen. Vor jedem Command Referenzen erneut validieren. Timeouts sind beobachtbare Fehler; sie dürfen nicht lediglich `push_warning()` auslösen und den Runner hängen lassen.

Ohne `on_error` kontrolliert FAILED abschließen. Mit Handler zuerst betroffenen Command canceln/cleanupen und dann springen. Keine automatische Command-Wiederholung bei Weltänderungen. Savefehler oder beschädigte Welt brauchen den in den Persistenz-/Battlekapiteln definierten Recovery-Vertrag; ein normaler Fehlerlabel-Sprung darf diesen nicht umgehen.

Debug-Modus kann bei Fehlern pausieren und Snapshot/Trace anzeigen. Release-Modus zeigt eine kurze Recoverymeldung, erzeugt Diagnose und stellt Kontrolle oder ein zulässiges Menü wieder her. Keine internen NodePaths oder Stacktraces im regulären Story-UI.

## 21. Addonstrategie und Quellen

### Dialogue Manager: vorhandene Integration behalten

Dialogue Manager liefert Dialogauswertung; Necota verwendet bereits eine eigene Gesprächsoberfläche. Der SequenceAdapter bleibt auf die installierte Version ausgerichtet. Die Upstream-Dokumentation beschreibt Dialogressourcen und scriptartige Inhalte; sie ist Ergänzung zum konkret installierten Code, keine automatische Versionsmigrationsanweisung. [Dialogue Manager, Projekt und Dokumentation](https://github.com/nathanhoad/godot_dialogue_manager/tree/v3.10.5), [offizielle Dokumentationsseite](https://dialogue.nathanhoad.net/).

### Phantom Camera: optionales Backend

Phantom Camera bietet virtuelle Kameras; Prioritäten bestimmen die aktive Kamera und Kameratransitionen. Necota kann einen Adapter dafür erstellen, wenn das bestehende CameraSystem an Grenzen stößt. Version und 3D-Signalverträge vor Integration fest pinnen. Ein bloßer Prioritätswechsel ersetzt keinen Sequence-Besitz-/Resume-Vertrag. [Offizielle Prioritätsdokumentation](https://phantom-camera.dev/priority), [PhantomCamera3D](https://phantom-camera.dev/core-nodes/phantom-camera-3d).

### GDrama: Architektur- und Workflowreferenz

GDrama beschreibt eine Importer-/Reader-/Animator-Pipeline und eine textartige Cutscene-Sprache mit Labels und Dialogpräsentation. Es dient als Referenz für Autorenworkflow und Erweiterbarkeit. Necota übernimmt daraus keine Runtimeabhängigkeit und keine zweite Flag-/Save-Domäne. [Offizielles GDrama-Repository](https://github.com/moraguma/GDrama).

### Godot

Für Speicherformat und Node-unabhängige Snapshots die offiziellen Hinweise zum Speichern berücksichtigen; Necotas WorldValueCodec/WorldSaveStore bleiben der konkrete Projektvertrag. [Godot: Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html).

Die Architekturentscheidungen und DSL in diesem Dokument sind projektspezifische Vorschläge, keine von den Addons zugesicherten Funktionen. Addons aus Asset Library/Store vor Einsatz auf Enginekompatibilität, Lizenz und konkrete Version prüfen; dieses Dokument fordert keine Installation.

## 22. Phasenweiser Umsetzungsplan

Die Reihenfolge liefert zuerst einen kleinen funktionierenden vertikalen Slice. Jede Phase endet mit einer im bestehenden MainGame startbaren Demo. Phase 3 nutzt einen kleinen Kampf-Continuation-Vertrag; Phase 4 verallgemeinert ihn für Checkpoints, Ortswechsel und Spielstandmigration. Phase 8 ist die konsolidierte Regression; sinnvolle Tests laufen bereits in jeder früheren Phase.

### Phase 0: Bestand bestätigen und Verträge festziehen

**Ziel:** Umsetzungsrisiken kennen, ohne vorhandene Systeme zu ersetzen.

**Tasks:**

1. Aktuellen Branch, Projektregeln, Engine-/Addonversionen und Architekturpläne prüfen.
2. MainGame-Lifecycle, Lock-Checks, LevelManager, DialogueSystem, CameraSystem und WorldLoader mit aktuellen Tests abgleichen.
3. StartResult/CommandResult/SequenceResult/BattleResult und Service-Bindung festlegen.
4. Minimalen ContentCatalog mit bestehenden Character-/Map-IDs definieren.
5. Shared-Claims, Cancellation und Cleanup-Vertrag dokumentieren; zuständige Dateien identifizieren.

**Abnahme:** keine Annahme separater Kampfszene oder fehlender Dialogintegration; jede neue API hat einen konkreten Besitzer. Nachgewiesene Integrationslücken sind als Tasks erfasst.

**Tests:** vorhandene Gameplay-Journey-, Dialogue-Context-, Level-Transitions-, Combat-Flee-, World-State- und Save-Tests als Ausgangsbaseline ausführen. Scheiternde Baseline unterscheiden von neuen Regressionen.

### Phase 1: MVP – Parser, Runner und sichere Regiekontrolle

**Ziel:** eine Textdatei startet im echten MainGame, wartet, setzt einen registrierten Bool-Flag und endet ohne hängenbleibende Eingaben.

**Tasks:**

1. SequenceProgram, SourceMap, Context, Handle und CommandRegistry implementieren.
2. Parser für Header, `wait`, `set`, `end`, `abort` und Kommentare/Strings; zunächst andere Commands ausdrücklich als nicht verfügbare Fähigkeit melden.
3. SequenceManager unter Systems mit Start/Busy/Cancel und terminalen Signals einbinden.
4. Run-ID, Zeit-/Instructionbudget und Cleanup-Stack einführen.
5. Besitzerverwaltung für den Sequence-Lock implementieren; Legacy-Locks kompatibel halten.
6. Minimalen Validator und Debugstart im bestehenden Debug-Menü ergänzen.
7. `.sequence`-Exportfilter und eine kleine MVP-Demo anlegen.

**Abnahme:** exklusiver Start; Abbruch gibt nur eigene Kontrolle frei; sofort abgeschlossene Handles hängen nicht; Fehler enthalten Datei/Zeile. Keine neuen Autoloads und keine Addonänderungen.

**Tests:** BOM/CRLF, `#` in String, escaped quotes, unbekannter Schlüssel, doppelte Parameter; Cancel während Wait; Start während fremdem Modal abweisen; zwei Starts im selben Frame; Scene-Abbau mitten im Run; Exportdemo lädt ihre Textdatei.

### Phase 2: Actors, Dialoge und strukturierte Parallelität

**Ziel:** der Actor-/Dialogteil von Beispiel A läuft mit vorhandenen Figuren und Gesprächsoberfläche; kleine Actors können sicher erzeugt und entfernt werden. Bis Phase 6 verwendet die Phasendemo eine reduzierte Datei ohne die noch nicht verfügbaren Musik-/Sequence-Shot-Befehle.

**Tasks:**

1. SequenceMarker/MapManifest und LiveActorRegistry ergänzen.
2. Bind/Spawn/Despawn mit CharacterRegistry-Vertrag und Besitzprüfung implementieren.
3. SequenceActorController für Bewegung, Orientierung, One-shots und Follow-/State-Übergabe bauen.
4. Parallel-all-Join, Claims und Cancellation der Geschwister implementieren.
5. SpeechBubble nach Designsystem ergänzen.
6. Öffentlichen Sequence-Dialogeinstieg mit Request-ID, single/conversation und User-close-Ergebnis ergänzen.
7. Bestehende Dialogkamera übergangsweise verwenden; weitergehende Sequence-Shots bis Phase 6 als Capability kennzeichnen.

**Abnahme:** Bewegung kollidiert nicht mit Follow/StateMachine; unzugänglicher Marker endet kontrolliert. Single-Dialog endet an Contentende, normaler NPC-Dialog behält Themenwahl. Temporärer Actor wird auch bei Fehler genau einmal entfernt.

**Tests:** duplicate Actor-ID, Actorverlust während Bubble/Move, fehlender Marker, blockierter Weg, ganzkörper move/animate-Claimkonflikt, zwei Actors parallel, Kindfehler canceliert Geschwister, Gespräch vorzeitig schließen, fremdes dialogue_ended ignorieren, Spawn+Cancel ohne Datenkopie-/Registry-Leak. Bestehende Conversation-UI-/Party-Leader-Tests bleiben grün.

### Phase 3: Kampf und Wiederaufnahme im laufenden Spiel

**Ziel:** Beispiel B erreicht in jeder terminalen Kampfsituation einen definierten Ausgang; keine Doppelbelohnung und keine gesperrten Kampfzüge.

**Tasks:**

1. CombatManager um accepted/rejected Startvertrag und Request-/Session-ID ergänzen.
2. Einmaligen terminalen Combat-Abschluss für Niederlage, echte Flucht, Abbruch und beidseitigen Ausfall definieren.
3. Controlled-party-Perspektive und Encounter-Policy implementieren; Teilnehmerermittlung beibehalten.
4. BattleAdapter/Handle vor Kampfstart registrieren; eigene Actor-/Input-/Kamerakontrolle übergeben und zurückholen.
5. Minimale PREPARED-/RESULT_READY-Daten und vollständigen Pre-/Post-Snapshot-Vertrag im SaveStore ergänzen; nötige Schemamigration nicht aufschieben.
6. Ergebnisblockparser, einfache Labels/Goto, Fehler-/Cancel-Labels und Pflichtzweige implementieren; default-Failsafe. Die dafür notwendige minimale Kontrollflussprüfung gehört bereits in diese Phase; der allgemeine Bedingungsparser folgt in Phase 5.
7. Atomaren reward_encounter-Effekt/Event-/Idempotenzschutz in Gameplay-Domäne bauen.
8. Minimalen sicheren LOSE-/ABORT-Recoverypfad bereitstellen, weil Game-over heute nicht vollständig angebunden ist.

**Abnahme:** LOSE/FLEE/ABORT/default vergeben keinen WIN-Reward; Fluchtversuch und echte Flucht unterscheidbar. Kampf bleibt im Level. Manual-control-Züge funktionieren unter suspendiertem Runner. Fremder/doppelter Combat-Abschluss bewegt den Cursor nicht.

**Tests:** WIN, Partywipe, einzelnes besiegtes Partymitglied, kompletter/teilweiser Escape, fehlgeschlagene Flucht, Gegnerflucht, beidseitiger Ausfall, Startablehnung, MainGame-Abbau, doppeltes Signal und Signal aus fremder Session. Schreibfehler vor Start verhindert Kampf; Postsave-Fehler verhindert Ergebniszweig. Reward-Duplikation nach Wiederaufnahme ausgeschlossen.

### Phase 4: Ortswechsel, Checkpoints und dauerhafte Persistenz

**Ziel:** Beispiel D sowie Kampf-Continuation funktionieren nach echtem Spielstandladen und MainGame-Neuaufbau.

**Tasks:**

1. SequenceState/Continuation validiert in WorldState, WorldValueCodec, WorldSaveStore und clear()/Migration integrieren; bestehenden Versionsstand beachten.
2. SaveAdapter mit Safe-point-Prüfung und eigener Leaseautorisierung bauen.
3. LevelManager-Transitionkern für Area- und Sequence-Einstieg gemeinsam nutzen; preflight und readiness ergänzen.
4. Marker-/Actor-Generation nach Levelwechsel invalidieren; dynamische World-Actor-Descriptors rekonstruieren.
5. WorldLoader-Ready-/Rollback-Pfad um Resume ergänzen; Autotrigger während Restore sperren.
6. Hash-/Contentversion-/Labelprüfung und erlaubte Migration definieren.
7. Completion, Effects und Weltzustand atomar speichern; begrenzte History.

**Abnahme:** alter Version-8-Spielstand lädt mit leerem SequenceState. PREPARED lädt Prebattle-Welt, RESULT_READY lädt Postbattle-Welt ohne zweiten Kampf. Levelwechsel funktioniert trotz eigener Sequence-Kontrolle und respektiert fremde Sperren. Fehler erhält vorige Welt konsistent.

**Tests:** Save/Load an jedem Beispielcheckpoint; Cancel/Crash vor und nach Transitioncommit; fehlendes Arrival/Ziellevel; nicht-ready Actor; veränderte Scriptdatei/fehlendes Resume-Label; corrupted sequence_state; Dynamic-Actor-Duplikat; schreibgeschützter Speicherort; Post-Reward-Reload. Bestehende Save-/WorldLoader-/LevelTransitions-Regressionen erneut ausführen.

### Phase 5: Bedingungen und Branching

**Ziel:** Beispiel C wählt anhand echten Weltzustands den richtigen Pfad; Quest-/Wissensregeln bleiben zentral.

**Tasks:**

1. Bereits vorhandene Label-/Goto-Unterstützung um if/elif/else, vollständige Flowanalyse und sicheren Expressionparser erweitern.
2. Whitelist-Queries für Bool-Flags, lokale Werte, Party, Knowledge, Quest und Actor-exists integrieren.
3. Fehlende WorldRules-Conditions/Effekte ergänzen, vorhandene atomare Regeln wiederverwenden.
4. Registrierte IDs/Typen, Effekt-IDs und Flowanalyse validieren.
5. Schleifenbudget und Fehlerhandlerbudget einführen; statisch unzulässige Sprünge ablehnen.
6. Erst bei Contentbedarf weitere Questdefinitionen samt Savevalidierung ergänzen.

**Abnahme:** keine GDScript-Ausführung aus Text; Wissensabfrage ist figurenspezifisch; Registryexistenz ist nicht Partyzugehörigkeit. Questübergänge sind geprüft, nicht per DSL überschreibbar. Endlosschleifen frieren das Spiel nicht ein.

**Tests:** Operatorpräzedenz/Kurzschluss, fehlendes local, falsche Typen, unbekannte Fact/Quest, Actor nur in einem Branch gebunden, Goto in verbotenen Block, zyklischer Sprung, bereits angewendeter Effekt, Fehler mitten in Effects-Transaktion. Bestehende WorldRules-/Quest-/Partytests weiterverwenden.

### Phase 6: Kamera, Audio und Präsentationspolish

**Ziel:** alle Beispiele laufen mit kontrollierten Shots, Musik und SFX; Cleanup lässt keine fremde Kamerakontrolle verloren gehen.

**Tasks:**

1. CameraAdapter an bestehendes CameraSystem und CameraEventHub anbinden.
2. Request-ID-/Besitzerstack, Cinematic-Presets und Marker-Shots ergänzen.
3. Dialog-/Combat-/Sequence-/Gameplay-Übergabe und Restore testen.
4. GameAudioSystem mit Musik-Crossfade, SFX-Voices, Scope und Ducking ergänzen.
5. AudioCatalog/Busvalidierung, Translationkeys und Bubble-Offscreen-Verhalten vervollständigen.
6. Optional Phantom Camera in isolierter Adapterdemo evaluieren; nur bei konkretem Vorteil integrieren und Version pinnen.
7. Skip bleibt in v1 deaktiviert; Pause und Cancel sind vollständig unterstützt. Eine spätere Skipfunktion müsste Storyeffekte und Barrieren ausdrücklich definieren.

**Abnahme:** CameraSystem ist alleiniger Kameraschreiber; Prioritätsübergabe funktioniert auch Dialog -> Kampf -> Sequence. Keine hängenbleibenden Tweens/SFX; Musikscope wird korrekt restauriert. UI entspricht NE_Theme.

**Tests:** Pause/Cancel mitten im Kameratween/Fade/SFX, fremdes Kameraabschlussereignis, Zielactor despawned, zwei Kameracommands parallel abweisen, aktiver Welttrack nach Sequence-Cleanup, fehlender Audio-Bus, Levelwechsel unter Kamerashot, Textblasen in verschiedenen Fenstergrößen. Bestehende DialogueCamera-/UIAudio-Tests weiterführen.

### Phase 7: Editor-, Debug- und Validierungstools

**Ziel:** Autoren finden Fehler vor dem Spielen; Codex kann reproduzierbare Diagnosepfade nutzen.

**Tasks:**

1. Projektweiten Validator mit Exitcode und menschenlesbaren Source-Diagnosen bauen.
2. Optionalen Importer für SequenceProgram, Syntaxhighlighting und Completion aus CommandRegistry ergänzen.
3. Debugpanel: Run/Sequence/Instruction, Sourcezeile, locals, Actorbindings, Leases, Claims, Handle-Status, Battle-Phase und Checkpoint anzeigen.
4. Debugstart mit expliziten WorldState-Testfixtures, Step, Pause, Cancel und Traceexport.
5. Marker-/Catalogmanifestgenerator plus Stale-Hash-Prüfung implementieren.
6. Sicheren Debugmodus anbieten: Simulation über Fake-Adapter statt versehentliche Gameplayeffekte. Step-Aktionen in echter Welt als wirksame Änderungen kennzeichnen.

**Abnahme:** CommandRegistry ist gemeinsame Quelle für Parser, Hilfe und Completion. Validator findet alle beschädigten Fixtures ohne Weltaufbau. Debugcancel hat denselben Cleanup wie regulärer Cancel; Debugtools beachten UI-Regeln.

**Tests:** fehlerhafte Filesammlung mit erwarteten Diagnosecodes/Zeilen; geänderter Catalog/Marker invalidiert Cache; Import/Export enthält Programme; Debug-Step über Immediate-/Wait-/Battlegrenzen; Dry-run verändert keine Flags/Inventare/Quests.

### Phase 8: Konsolidierte Tests und Releaseabnahme

**Ziel:** Integrationsverträge und Recovery sind nachweisbar belastbar, auch in exportierter Anwendung.

**Tasks:**

1. Vorhandene Testszene-Konvention verwenden: check()-Zähler, deferred Start und Prozess-Exitcode; Tests in CI/headless dort ausführen, wo Engine-/Renderanforderungen dies erlauben.
2. Parser-/Evaluatorfixtures, deterministische Fake-Adapter-Runner-Tests und echte MainGame-Integration kombinieren.
3. Failure-Injection für verspätete Signals, Abbau, Savefehler, Actorverlust und fehlende Readiness ergänzen.
4. Save-Migrationsfixtures aller unterstützten Versionen erhalten.
5. Vier Dokumentbeispiele als echte Contentfixtures aufnehmen; sämtliche terminalen Battle-Zweige abdecken.
6. Export-Smoketest für Text-/Resourceimports, Dialoge, Levelwechsel, Audio und Resume ausführen.
7. Dokument mit implementierten Commands, tatsächlichen APIs und verbleibenden Grenzen aktualisieren.

**Abnahme:** keine Input-/Camera-/Actor-Leases, Listener oder temporären Nodes nach terminalem Run. Alle Pflichtausgänge und Snapshotgrenzen getestet. Ein gestarteter Run erreicht Completion, kontrollierten Abbruch, Fehler oder explizit wartenden Spielerzustand; keine unbeobachtete ewige Await.

**Sinnvolle Testgruppen:**

- Parser: Syntax, Typen, Blocks, SourceMap, Vollständigkeit der Branches.
- Runner: unmittelbarer Abschluss, all-Join, Claims, Pause/Cancel, Timeout und Budget.
- Domain: richtige Party-/Knowledge-/Questabfragen, Effektransaction und Rewardidempotenz.
- Integration: Spielkontrolle, Dialogmodi, Bewegung, Kampf, Kamera-/Audioübergabe und Levelreadiness.
- Persistenz: vollständige Welt+Cursor-Konsistenz, Migrationsablehnung/-annahme, Pre-/Postbattle und Crashsimulation.
- Regression: bestehende Gameplay-Journey, WorldLoader, SaveMenu, WorldRules, QuestProgress, PartyState, DialogueContext, DialogueCamera, CombatFlee und LevelTransitions.

Keine Tests schreiben, die nur jede private Methode nachbilden. Vorrang haben beobachtbare Resultate: richtige Branches, einmalige Effekte, konsistente Welt und zurückgegebene Kontrolle.

## 23. Erste konkrete Implementierungsaufgabe für Codex

Als ersten Lieferumfang **Phase 0 und Phase 1** umsetzen:

1. Aktuellen NECOTA2D-Stand und Baseline prüfen.
2. SequenceManager/Runner unter MainGame mit minimalem Parser/Validator und Handlevertrag integrieren.
3. Beispiel `sequence_mvp.sequence` mit `wait`, registrierter Bool-Flag und `end` startbar machen.
4. Busy, Cancel, Cleanup und Source-Diagnosen verifizieren.
5. Exportfähigkeit der DSL-Datei nachweisen.
6. Erst danach Actors/Dialog/Battle ausbauen; keine vollständige DSL-Implementierung in einem unprüfbaren großen Schritt.

Die v1-Spezifikation beschreibt das Endziel. Während des MVP muss ein Script, das spätere Commands verwendet, klar mit „Fähigkeit noch nicht implementiert“ abgelehnt werden. Es darf solche Zeilen nicht ignorieren und dadurch einen scheinbar erfolgreichen, unvollständigen Storyablauf erzeugen.
