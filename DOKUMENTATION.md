# NECOTA 2.5D - Technische Dokumentation

Diese Dokumentation beschreibt die implementierten Systeme und deren Verwendung.

---

## Inhaltsverzeichnis

1. [Projektstruktur](#projektstruktur)
2. [Schrittgeräusche-System](#schrittgeräusche-system)
3. [Spieler-Bewegung & Sprint](#spieler-bewegung--sprint)
4. [Kamera-System](#kamera-system)
5. [Hitbox/Hurtbox-System](#hitboxhurtbox-system)
6. [State Machine](#state-machine)
7. [Kampfsystem](#kampfsystem)
8. [Hauptmenü](#hauptmenü)

---

## Projektstruktur

```
NECOTA2D/
├── src/                          # Verhalten: Scripts, Szenen, Spieldaten
│   ├── core/                     # Autoloads, Manager, Spiel-Root
│   ├── gameplay/                 # Character, Combat, Interaction, Inventory, …
│   ├── world/                    # Levels und Welt-Objekte
│   ├── resources/                # Spieldaten (.tres, Resource-Scripts)
│   ├── ui/                       # HUD, Menüs, Inventar-UI
│   └── debug/
├── assets/                       # Visuelle und Audio-Assets
│   ├── characters/
│   ├── tilesets/
│   ├── environments/
│   ├── items/
│   ├── audio/
│   └── fonts/
├── addons/
└── project.godot
```

---

## Schrittgeräusche-System

### Übersicht

Das System erkennt automatisch die Oberfläche unter dem Charakter und spielt passende Schrittgeräusche ab.

### Dateien

| Datei | Beschreibung |
|-------|--------------|
| `src/gameplay/character/footsteps/SurfaceType.gd` | Enum für Oberflächentypen |
| `src/gameplay/character/footsteps/FootstepSounds.gd` | Resource für Sound-Bibliotheken |
| `src/gameplay/character/footsteps/FootstepPlayer.gd` | Hauptkomponente |
| `src/gameplay/character/footsteps/SurfaceDefinition.gd` | Helper für Oberflächen |
| `src/resources/characters/footsteps/DefaultFootsteps.tres` | Beispiel-Resource |

### Oberflächentypen

```gdscript
enum Type {
    GRASS,    # Gras, Wiese
    STONE,    # Stein, Fels
    WOOD,     # Holz, Bretter
    SAND,     # Sand, Strand
    WATER,    # Wasser, Pfützen
    METAL,    # Metall, Gitter
    DIRT,     # Erde, Schlamm
    SNOW,     # Schnee, Eis
    DEFAULT   # Fallback
}
```

### Verwendung

#### 1. FootstepSounds Resource erstellen

```
Rechtsklick im FileSystem → New Resource → FootstepSounds
```

Dann im Inspector die Sound-Arrays befüllen:
- `grass_sounds`: Array von AudioStream für Gras
- `stone_sounds`: Array von AudioStream für Stein
- etc.

#### 2. FootstepPlayer zu Charakter hinzufügen

```
Charakter (CharacterBody3D)
└── FootstepPlayer (Node3D)
    └── Script: FootstepPlayer.gd
```

Im Inspector:
- `footstep_sounds`: Die erstellte FootstepSounds Resource zuweisen
- `step_interval`: Zeit zwischen Schritten (Standard: 0.35s)
- `sprint_step_interval`: Zeit beim Sprinten (Standard: 0.25s)

#### 3. Oberflächen markieren

**Option A: Metadaten (empfohlen)**

Im StaticBody3D der Oberfläche:
```
Inspector → Meta → Add Meta
Name: surface_type
Value: "grass"  (oder stone, wood, sand, water, metal, dirt, snow)
```

**Option B: SurfaceDefinition Script**

```
StaticBody3D
└── SurfaceDefinition (Node)
    └── Script: SurfaceDefinition.gd
    └── surface_type: "grass"
```

**Option C: Gruppen**

Den StaticBody3D zur Gruppe hinzufügen:
- `grass`, `stone`, `wood`, `water`, etc.

#### 4. Im Walk-State integrieren

```gdscript
# In stateWalk.gd - bereits implementiert

func Enter() -> void:
    if player.footstep_player:
        player.footstep_player.start_walking(is_sprinting)

func Exit() -> void:
    if player.footstep_player:
        player.footstep_player.stop_walking()
```

#### 5. Für NPCs verwenden

```gdscript
# In NPC-Script
@onready var footstep_player: FootstepPlayer = $FootstepPlayer

func start_moving():
    footstep_player.start_walking(false)

func stop_moving():
    footstep_player.stop_walking()

# Oder manuell einen Schritt auslösen:
func on_animation_step():
    footstep_player.play_step()
```

### Parameter

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `footstep_sounds` | FootstepSounds | null | Sound-Bibliothek |
| `step_interval` | float | 0.35 | Sekunden zwischen Schritten |
| `sprint_step_interval` | float | 0.25 | Sekunden beim Sprint |
| `raycast_length` | float | 2.0 | Länge des Boden-Raycasts |
| `pitch_variation` | float | 0.1 | Zufällige Tonhöhenvariation |
| `enabled` | bool | true | System aktiviert |

### Lautstärke pro Oberfläche

| Oberfläche | Standard dB | Charakter |
|------------|-------------|-----------|
| Gras | -5.0 | Leise, gedämpft |
| Stein | 0.0 | Normal, hallend |
| Holz | -2.0 | Leicht gedämpft |
| Sand | -8.0 | Sehr leise |
| Wasser | 0.0 | Platschend |
| Metall | +2.0 | Laut, metallisch |
| Erde | -3.0 | Gedämpft |
| Schnee | -6.0 | Leise, knirschend |

---

## Spieler-Bewegung & Sprint

### Übersicht

Die Bewegung wird über eine State Machine gesteuert. Der Sprint hat eine Anlaufzeit (Beschleunigung).

### Parameter (stateWalk.gd)

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `base_speed` | float | 1.0 | Normale Gehgeschwindigkeit |
| `sprint_speed` | float | 2.5 | Maximale Sprintgeschwindigkeit |
| `acceleration` | float | 4.0 | Beschleunigung beim Sprinten |
| `deceleration` | float | 6.0 | Abbremsen nach Sprint |

### Steuerung

| Taste | Aktion |
|-------|--------|
| W/A/S/D | Bewegung |
| Shift (halten) | Sprint |
| E | **Interaktion** — öffnet das Kontextmenü für Objekte in Reichweite (Gruppe `interactable`) |

### Funktionsweise Sprint

```
Start Sprint (Shift gedrückt):
├── current_speed steigt graduell von base_speed → sprint_speed
├── acceleration bestimmt die Geschwindigkeit des Anstiegs
└── Schrittgeräusche wechseln zu sprint_step_interval

Ende Sprint (Shift losgelassen):
├── current_speed sinkt graduell von sprint_speed → base_speed
├── deceleration bestimmt die Geschwindigkeit des Absinkens
└── Schrittgeräusche wechseln zurück zu step_interval
```

---

## Kamera-System

### Übersicht

`CameraSystem` unter `MainGame/Systems` besitzt die einzige Welt-`Camera3D`. Im Gameplay folgt sie dem Party-Leader mit Mode-7-Blickwinkel und Look-Ahead (Goldener Schnitt). Level liefern optional Grenzen und Kamera-Settings; das System entscheidet Follow, Clamp, Zoom und Dialog-Shots.

Es gibt **keine** zweite Kamera auf NPCs oder dem Player. Charaktere stellen nur `Marker3D`-Referenzpunkte bereit.

### Parameter

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `follow_distance` | float | 8.0 | Abstand hinter dem Spieler |
| `camera_height` | float | 6.0 | Höhe über dem Spieler |
| `pitch_angle` | float | -45.0 | Neigungswinkel (Mode7: -30 bis -60) |
| `smooth_speed` | float | 5.0 | Glättung der Bewegung |
| `look_ahead_distance` | float | 3.0 | Vorausschau in Blickrichtung |
| `dialogue_transition_sec` | float | 0.35 | Dauer der Dialog-Kamera-Tweens |

### Goldener Schnitt

Die Kamera positioniert den Spieler nach dem Goldenen Schnitt:
- **38.2%** des Bildschirms hinter dem Spieler
- **61.8%** des Bildschirms in Blickrichtung

```
Spieler schaut nach Norden:
┌─────────────────────────┐
│                         │
│      61.8% sichtbar     │  ← Mehr Sicht nach Norden
│                         │
│           ●             │  ← Spieler
│      38.2% sichtbar     │
└─────────────────────────┘
```

### Mode7-Effekt anpassen

```gdscript
# Flacher (mehr Mode7-Gefühl):
pitch_angle = -35.0
camera_height = 4.0
follow_distance = 10.0

# Steiler (mehr Top-Down):
pitch_angle = -60.0
camera_height = 8.0
follow_distance = 6.0
```

### Dialogkamera

Während eines Dialogs hält `CameraSystem` das Follow an und bewegt dieselbe `Camera3D` per Tween zu Shot-Markern. `DialogueSystem` entscheidet nur **wen** und **welchen Shot**; es kennt keine NodePaths zur Kamera.

```
DialogueSystem
  dialogue_started / dialogue_line_changed / dialogue_ended
        ↓
CameraSystem.show_dialogue_shot(character, shot, look_character, look, shot_tags)
        ↓
CameraSystem.events.shot_changed / transition_finished / control_returned
        ↓
Position: Character/DialogueCameraPoints/<Shot>
Blick:    Character/DialogueLookTargets/<Eyes|Head|Mouth>
FOV:      DialogueCameraMarker.fov (optional, parallel zum Transform-Tween)
```

Nur das `CameraSystem` bewegt die Kamera und sendet die Events. Andere Systeme hören, sie setzen keine `Camera3D`-Properties.

#### Was ist ein DialogueCameraPoint?

Ein `Marker3D` unter `DialogueCameraPoints` (bevorzugt mit Script `DialogueCameraMarker`). Der Node-Name legt den Shot fest (`Close`, `Medium`, `Wide`, `Profile`, `OverShoulder`). Optional: `shot`-Enum, `weight`, `tags`, `fov`, `transition_sec` und `transition_ease`.

Die Marker sind **Kamerastandpunkte**, keine Kameras. +Z zeigt nach vorne (Blickrichtung des Charakters). `DialogueCameraPoints` dreht sich zur `Playable.facing_direction`, damit die Marker mit dem Modell mitdrehen.

Standard-Tags, Gewichte und Kamera der Vorlage (Gameplay-FOV ist 50):

| Shot | Tags | Weight | FOV | Duration | Ease |
|------|------|--------|-----|----------|------|
| Close | emotional, intimate | 5 | 62 | 0.35 | Out |
| Medium | neutral, conversation | 2 | 50 | 0.35 | InOut |
| Wide | neutral, conversation | 2 | 40 | 0.50 | InOut |
| Profile | dramatic | 1 | 48 | 0.40 | InOut |
| OverShoulder | conversation | 2 | 52 | 0.35 | InOut |

`fov = 0` oder ein Marker ohne Script behält den aktuellen Kamera-FOV. `transition_sec < 0` nutzt `CameraSystem.dialogue_transition_sec`. Leere Marker-Tags fallen auf die Defaults zurück. Nur **sichtbare** Marker zählen.

#### Kamera-Punkte an einem NPC oder Player hinzufügen

1. Charakter-Szene öffnen (NPC oder Player).
2. Instanz von `src/gameplay/character/camera/dialogue_camera_points.tscn` als Kind des Charakters einfügen (nicht unter `Model`).
3. Marker im Editor verschieben. Unnötige Shots können unsichtbar geschaltet werden — unsichtbare Marker werden ignoriert.
4. Eigene Marker reichen: `Marker3D` anlegen und `Close` / `Medium` / … nennen. Das Marker-Script ist für Gewichtungen, Tags und FOV nötig.

`EnemyNPC` hat absichtlich keine Punkte: Dialoge funktionieren trotzdem über eine berechnete Standardposition.

#### Was ist ein DialogueLookTarget?

Ein `Marker3D` unter `DialogueLookTargets`. Der Name legt das Blickziel fest (`Eyes`, `Head`, `Mouth`). Die Kamera steht am Shot-Marker und **schaut** auf dieses Ziel. Ohne Look-Targets gilt weiter `look_height` (Brusthöhe).

#### Look-Targets hinzufügen

1. Charakter-Szene öffnen.
2. Instanz von `src/gameplay/character/camera/dialogue_look_targets.tscn` als Geschwister von `DialogueCameraPoints` einfügen (nicht unter `Model`).
3. Marker an Augen, Kopf oder Mund schieben. Unnötige Ziele unsichtbar schalten.

#### Shot in einem Dialog setzen

Bestehende Dialogue-Manager-Tags, keine neue Datenstruktur:

```
Elara: Endlich jemand! [#camera=close,look=eyes]
Dannerman: Ich kümmere mich darum. [#camera=close,look=eyes]
Elara: Viel Glück! [#camera=over_shoulder,look=eyes]
Test-NPC: Ich habe dich vermisst. [#camera=random,shots=emotional+intimate]
```

Kurzform: `[#close]`, `[#look=head]`, `[#target=mouth]`. Ohne `look`-Tag: Close/Profile/OTS → Eyes, Medium/Wide → Head, falls Marker existieren.

`[#look=none]` erzwingt die alte `look_height`-Ausrichtung.

Komma trennt Dialogue-Manager-Tags. Mehrere Shot-Tags deshalb mit `+`: `shots=emotional+intimate`. Aliase: `shot`, `camtags`, `camtag`, `tags`.

Sprecher wird über den Dialognamen dem Player (`Dannerman`) oder dem aktiven NPC zugeordnet. Abweichend: `[#camera=close,subject=player]`.

Aus einer Mutation: `do request_shot("close", "player", "eyes")` oder `do request_shot("random", "", "", "emotional+intimate")`.

API für andere Systeme:

```gdscript
camera_system.show_dialogue_shot(npc, CameraShot.Kind.CLOSE)
camera_system.show_dialogue_shot(npc, "medium", null, CameraShot.Look.HEAD)
camera_system.show_dialogue_shot(npc, "random", null, CameraShot.Look.AUTO, PackedStringArray(["emotional"]))
```

#### RANDOM, Tags und Gewichte

Auswahlreihenfolge:

1. Expliziter Shot (`[#camera=close]`) — Tags werden ignoriert
2. `RANDOM` + passende Marker-Tags (OR: ein gemeinsamer Tag reicht)
3. Gewichtete Zufallsauswahl unter den Treffern
4. Kein Tag-Treffer → gewichtet unter allen sichtbaren Markern
5. Kein Marker → berechnete Position (`MEDIUM`)

`[#camera=random]` ohne `shots=` nutzt nur Schritt 3–5. Ein Shot wird nur gewählt, wenn der Charakter einen sichtbaren Point dafür hat. Der zuletzt verwendete Shot wird übersprungen, sofern ein anderer verfügbar ist.

#### FOV-Übergänge

Dieselbe Welt-`Camera3D` ändert Position und `fov` in **einem** parallelen Tween (`TRANS_SINE`). Ein neuer Shot bricht den laufenden Tween ab und startet vom aktuellen Zustand. Beim Dialogende werden gespeicherte Gameplay-Position **und** Gameplay-FOV wiederhergestellt (Scroll-Zoom über `follow_distance` bleibt unberührt).

#### Fehlende Kamera-Punkte

| Situation | Verhalten |
|-----------|-----------|
| Gewünschter Shot fehlt (z. B. `CLOSE`) | Fallback `MEDIUM`, dann `WIDE` / `PROFILE` / `OVER_SHOULDER`, dann erster Marker |
| Character hat `DialogueCameraPoints` ohne Marker | Berechnete Position vor dem Charakter |
| Character hat gar keine Punkte | Dialog läuft; berechnete Position |
| NPC wird während des Dialogs entfernt | Keine Null-Zugriffe; Kamera bleibt bzw. stellt Gameplay wieder her |
| Dialog endet während eines Tweens | Laufender Tween wird beendet, Gameplay-Kamera fährt zurück |
| `Eyes` fehlt | Fallback `Head`, dann `Mouth`, dann `look_height` |
| Character hat keine Look-Targets | Blick bleibt auf `look_height` (wie zuvor) |

#### Rückkehr zur Gameplay-Kamera

Bei `dialogue_ended` ruft `CameraSystem.restore_gameplay_camera()` auf: der Dialog-Tween wird abgebrochen, die Kamera fährt zur gespeicherten Follow-Position, der Gameplay-FOV wird zurückgesetzt, danach greifen Follow und Scroll-Zoom wieder. Anschließend: `events.control_returned`.

#### Camera Events

Kein globaler Event-Bus. Listener hängen am bestehenden `CameraSystem`:

```gdscript
var hub := CameraSystem.instance.events
hub.listen_shot_changed(_on_shot_changed)

func _on_shot_changed(event: CameraShotEvent) -> void:
	# event.character, event.shot, event.look_target, event.duration, event.fov, event.source
	pass

func _exit_tree() -> void:
	if CameraSystem.instance:
		CameraSystem.instance.events.unlisten_shot_changed(_on_shot_changed)
```

| Signal | Wann | Payload |
|--------|------|---------|
| `shot_changed` | aufgelöster Shot startet (inkl. Transition) | `CameraShotEvent` |
| `transition_finished` | Tween fertig oder Duration 0; nicht bei Abbruch | `CameraShotEvent` |
| `control_returned` | Gameplay-Kamera wieder aktiv (Dialogende, Levelwechsel, `set_enabled(false)`) | — |

`source`: `dialogue` (jetzt), `restore` (Rückfahrt), `cinematic` (reserviert). Ein späteres CinematicSystem würde `show_dialogue_shot(..., source=&"cinematic")` aufrufen und dieselben Events für Animation/Licht/Audio nutzen — ohne die Kamera selbst zu bewegen.

Levelwechsel und `set_enabled(false)` brechen einen Dialog-Shot ab und senden `control_returned`, ohne `transition_finished`.

### Player-Occlusion (X-Ray)

Die Mode-7-Kamera dreht nicht. Steht Dannerman hinter einer Wand (`GridMap` / Level-Mesh), bleibt die normale Modelldarstellung unverändert; ein zweiter transparenter Shader-Pass zeichnet nur **verdeckte** Pixel (Depth-Vergleich).

`OcclusionVisual` sitzt als Kind am Player, nicht in `Player.gd`.

| Parameter | Bedeutung |
|-----------|-----------|
| `xray_color` | Silhouettenfarbe |
| `xray_alpha` | Transparenz der Silhouette |
| `outline_strength` | Rim-/Konturstärke |
| `glow_strength` | dezentes Emission-Leuchten |
| `transition_sec` | Fade zwischen normal und X-Ray |
| `use_raycast_gate` | An: wenige Rays Kamera→Körper steuern den Fade (Hysterese). Aus: nur Depth-Shader |
| `occlusion_mask` | Physics-Layer der Rays |
| `debug_show_player_occlusion` | Label3D mit Zustand und letztem Collider |

Shader: `src/gameplay/character/player/occlusion/player_xray.gdshader`.

---

## Hitbox/Hurtbox-System

### Konzept

```
Hurtbox (Verursacht Schaden) ──► Hitbox (Empfängt Schaden)
         Area3D                        Area3D
```

### Hitbox.gd

```gdscript
class_name Hitbox extends Area3D

signal Damaged(damage: int)

func TakeDamage(damage: int) -> void:
    Damaged.emit(damage)
```

### Hurtbox.gd

```gdscript
class_name HurtBox extends Area3D

@export var damage: int = 1

func _ready() -> void:
    area_entered.connect(AreaEntered)

func AreaEntered(a: Area3D) -> void:
    if a is Hitbox:
        a.TakeDamage(damage)
```

### Verwendung

```gdscript
# In einem zerstörbaren Objekt (z.B. Plant):
@onready var hitbox: Hitbox = $Hitbox

func _ready():
    hitbox.Damaged.connect(on_damaged)

func on_damaged(damage: int):
    health -= damage
    if health <= 0:
        queue_free()
```

### Collision Layers

| Layer | Name | Verwendung |
|-------|------|------------|
| 1 | Player | Spieler-Körper |
| 2 | PlayerHurt | Vom Spieler ausgelöste Schadens-/Kontaktbereiche (z. B. später Items, Effekte) |
| 5 | Walls | Hindernisse |
| 9 | NPC | NPCs |
| 256 | Hitbox | Schadens-Empfänger |

---

## State Machine

### Ausrichtung

Erkundung nutzt die State Machine für **Bewegung** und **Interaktion** (Kontextmenü). **Kampf** ist rundenbasiert und läuft direkt in der Erkundungs-Welt (kein Szenenwechsel) – siehe [Kampfsystem](#kampfsystem). Für Kampfteilnehmer übersteuern `CombatWait`/`CombatTurn` die normale Idle/Walk/ActionMenu-Steuerung, solange sie an einer Kampfsitzung beteiligt sind.

### Struktur (Dannerman, Leader/spielbarer Charakter)

```
StateMachine (Node)
├── Idle (Node)        → state_idle.gd
├── Walk (Node)         → state_walk.gd
├── ActionMenu (Node)   → state_action_menu.gd
├── CombatWait (Node)   → state_combat_wait.gd     (Kampfsystem)
├── CombatTurn (Node)   → state_combat_turn.gd     (Kampfsystem)
└── PartySkills (Node)  → state_party_skills.gd    (Party-Fähigkeiten, neu)
```

### Struktur (Party-Follower, z.B. Shalka)

Follower werden nie durch WASD/Interact gesteuert (Bewegung läuft komplett über `PartyFollower._update_follow`) – ihre StateMachine bleibt deshalb außerhalb des Kampfes deaktiviert (`process_mode = PROCESS_MODE_DISABLED`) und hat bewusst kein `Walk`/`ActionMenu`:

```
StateMachine (Node)
├── Idle (Node)       → state_follower_idle.gd   (kein Input-Handling)
├── CombatWait (Node) → state_combat_wait.gd      (identisch zum Leader)
└── CombatTurn (Node) → state_combat_turn.gd      (identisch zum Leader)
```

`Playable.enter_combat_mode()`/`exit_combat_mode()` schalten `process_mode` gezielt für die Dauer der eigenen Kampfteilnahme ein/aus – dadurch sind inzwischen **alle** Partymitglieder im Kampf manuell steuerbar (gleiches Kampfmenü wie der Leader), nicht mehr nur er. `NPCCombatBrain` steuert nur noch echte NPCs/Gegner ohne eigene `CombatTurn`-State (siehe Kampfsystem). Das alte, nie eingebundene `state_attack.gd` (Echtzeit-Overworld-Angriff) bleibt unangetastet im Projekt, wird aber von nichts referenziert.

### State-Basis (state.gd)

```gdscript
class_name State extends Node

var player: Player

func Enter() -> void:
    pass

func Exit() -> void:
    pass

func Process(_delta: float) -> State:
    return null  # null = bleibe in diesem State

func Physics(_delta: float) -> State:
    return null

func HandleInput(_event: InputEvent) -> State:
    return null
```

### Neuen State erstellen

```gdscript
class_name StateNewState extends State

@onready var idle: State = $"../Idle"

func Enter() -> void:
    player.UpdateAnimation("new_state")

func Exit() -> void:
    pass

func Process(_delta: float) -> State:
    # Logik hier
    if some_condition:
        return idle  # Wechsel zu Idle
    return null      # Bleibe hier

func HandleInput(_event: InputEvent) -> State:
    if _event.is_action_pressed("SomeAction"):
        return some_other_state
    return null
```

---

## Kampfsystem

### Übersicht

Kämpfe finden **in der normalen Spielwelt** statt (Chrono-Trigger/Ultima-6-Stil) – keine separate Kampfszene, keine zweite HP/MP-Buchhaltung. Jeder Charakter (Spieler, Party-Begleiter, NPC) ist über sein `CharacterResource`-Charakterblatt gleichermaßen angreifbar. Wer sich an einem ausgebrochenen Kampf beteiligt und auf welcher Seite, entscheidet ausschließlich das Beziehungssystem – nicht Party-Zugehörigkeit oder ein statisches "Gegner"-Flag.

### Dateien

| Bereich | Datei |
|---|---|
| Beziehungsabfrage | `src/gameplay/combat/relationships/relationship_service.gd` |
| Teilnehmer-Klassifikation | `src/gameplay/combat/engine/combat_participant_resolver.gd` |
| Kampf-Sitzung/Initiative | `src/gameplay/combat/engine/combat_session.gd`, `combat_participant.gd` |
| Einstiegspunkt (kein Autoload, Node unter `MainGame/Systems`) | `src/core/managers/combat_manager.gd` |
| Aktion & Auflösung | `src/gameplay/combat/engine/combat_action.gd`, `combat_resolver.gd` |
| Sichtlinie | `src/gameplay/combat/engine/combat_line_of_sight.gd` |
| Einfache Gegner-KI | `src/gameplay/combat/engine/npc_combat_brain.gd` |
| Spieler-Kampfmenü | `src/gameplay/character/state_machine/state_combat_wait.gd`, `state_combat_turn.gd` |
| Balancing-Konstanten | `src/resources/combat/combat_balance.gd` |
| Fähigkeiten (Magie, Gesang, …) | `src/resources/abilities/ability_definition.gd` + `src/resources/abilities/definitions/*.tres` |
| Item-Nutzungsarten (stechen/schlagen/werfen) | `src/resources/items/item_usage_mode.gd` |
| Party-Fähigkeiten-Menü außerhalb des Kampfes | `src/gameplay/character/state_machine/state_party_skills.gd`, `src/gameplay/combat/engine/party_ability_resolver.gd` |
| Kampfreihenfolge-HUD | `src/ui/hud/combat_order_hud.gd`/`.tscn`, `combat_order_entry.gd`/`.tscn` |
| Aktions-Feedback ("wer tut was") | `src/gameplay/combat/engine/combat_action_outcome.gd`, `combat_narrator.gd`, `src/ui/hud/combat_log_hud.gd`/`.tscn` |

### Beziehungen entscheiden über Kampfseiten

`CharacterResource.beziehungen: Array[RelationshipEntry]` verweist per `target_id` auf einen anderen Charakter (`character_id`) oder eine Fraktion (`Faction.faction_id`, `CharacterResource.faction_ids`), mit einer Wertung von **-10 (feindlich) bis +10 (absolut intim)** (`CharacterEnums.BEZIEHUNG_MIN/MAX`). `RelationshipService.get_disposition(A, B)` liest das gerichtet aus `A`s eigenem `beziehungen`-Array (nicht symmetrisch) – ein Individual-Eintrag hat Vorrang vor Fraktions-Einträgen.

Bricht ein Kampf aus, sammelt `CombatParticipantResolver.scan_candidates()` alle Charaktere aus der Gruppe `"combat_reactive"` im Wahrnehmungsradius (`CombatBalance.AWARENESS_RADIUS`) und ordnet jeden per `classify()` einer Seite zu: positive Beziehung zum Opfer → steht ihm bei; positive Beziehung zum Angreifer → unterstützt ihn; sonst neutral (schaut zu, wird kein Kampfteilnehmer). Das gilt uneingeschränkt auch für die eigene Party – ein Party-Mitglied mit hoher Beziehung zum Angegriffenen wechselt automatisch die Seite. Fällt ein Kandidat mangels gepflegter `beziehungen`-Einträge auf neutral zurück, greift `CombatManager._default_party_side()`: eigene Party-Mitglieder stehen sich trotzdem automatisch bei (Party-Zugehörigkeit als starkes Vorgabe-Signal), eine echte Beziehung kann das weiterhin übersteuern.

### Initiative statt fester Rundenreihenfolge

`CombatSession` führt kein starres Rundenschema, sondern ein Energiemeter pro Teilnehmer: proportional zur `GEWANDHEIT` steigt `initiative_meter` jeden Tick; bei Erreichen von `CombatBalance.INITIATIVE_THRESHOLD` kommt der Teilnehmer in die Zug-Warteschlange, der Überschuss bleibt erhalten. Ein doppelt so flinker Charakter sammelt so zwei Zugberechtigungen an, bevor ein langsamer die erste bekommt.

### Kampfmodus statt Szenenwechsel

`Playable.enter_combat_mode(session)`/`exit_combat_mode()` übersteuern nur für tatsächliche Teilnehmer die eigene State Machine (Wechsel zu `CombatWait`/`CombatTurn`) – **kein** globaler `GameState`-Input-Lock. Unbeteiligte Charaktere laufen währenddessen normal weiter. **Alle** Partymitglieder (Leader und Follower, siehe [State Machine](#state-machine)) haben einen `CombatTurn`-State mit demselben Kampfmenü und werden dadurch automatisch manuell erkannt (`CombatManager._has_manual_control()`); nur echte NPCs/Gegner ohne eigene `CombatTurn`-State werden von `NPCCombatBrain` gesteuert, sobald sie an der Reihe sind – sonst bliebe die Initiative-Uhr auf ihrem Zug hängen.

### Zug-Optionen

Das Kampfmenü (`state_combat_turn.gd`) bietet fünf Aktionen:

- **Gegenstand**: nur was in der Hand oder am Gürtel getragen wird (`Inventory.get_combat_usable_items()`, Slots `primaer_hand`/`nebenhand`/`waffe`/`guertel_1-3`), mit den am Gegenstand definierten Nutzungsarten (`ItemData.usage_modes`, z.B. Messer: stechen/werfen; Stein: schlagen/werfen).
- **Fähigkeit**: `AbilityCatalog.get_available_for(character)` filtert `AbilityDefinition`-Ressourcen danach, ob das zugehörige RPG-Talent (`source_skill_id`, z.B. `magiekunde`, `bardenkunst`) gelernt und hoch genug ist – die Brücke zwischen dem bestehenden Talentsystem und nutzbaren Kampf-Fähigkeiten. Nur `DAMAGE`/`HEAL` sind implementiert; `BUFF`/`DEBUFF`/`UTILITY` melden ehrlich `"effect_not_implemented"` (kein Status-Effekt-System vorhanden).
- **Bewegen**: fester Schritt relativ zur Blickrichtung (`CombatBalance.MOVE_STEP_DISTANCE`), keine Kollisionsprüfung – Detailmechanik bewusst einfach gehalten.
- **Reden**: öffnet den vorhandenen Dialog des Ziels (`NPCInteraction.perform_action("talk", …)`), falls vorhanden.
- **Fliehen**: Erfolgschance aus der Differenz der eigenen Gewandheit zur durchschnittlichen Gewandheit der Gegenseite (`CombatBalance.FLEE_*`).

### Sichtlinie

`CombatLineOfSight.has_clear_line(from, to)` castet einen Ray auf Augenhöhe zwischen zwei Charakteren; die Maske deckt Wände **und andere Charakterkörper** ab (anders als die reine Kamera-Verdeckung von `OcclusionVisual`, aus deren Raycast-Muster diese Utility adaptiert ist). Aktionen mit `requires_line_of_sight = true` (Standard) blenden Ziele ohne freie Sicht im Menü als nicht wählbar aus und prüfen erneut bei der Ausführung.

### Automatische Verteidigung

Kein manueller "Verteidigen"-Zug: `CombatResolver.resolve_damage()` würfelt bei jedem Treffer automatisch Ausweichen (aus der Gewandheit des Ziels) und mindert den Schaden über die Robustheit des Ziels – für jeden Charakter, jederzeit.

### Kampfreihenfolge-HUD

`CombatOrderHud` (oben rechts) zeigt während eines Kampfes die Zugreihenfolge: aktiver Teilnehmer zuerst (hervorgehoben), danach `turn_queue` (bereits bereit), danach der Rest nach `initiative_meter` absteigend sortiert (Schätzung, da sich die Geschwindigkeit laufend ändert). Grün/Rot markiert eigene Party (`Player`/`PartyFollower`) vs. alles andere, unabhängig davon, wer den Kampf ausgelöst hat. Bindet an `CombatManager.combat_started`/`combat_ended` zum Ein-/Ausblenden; `CombatSession.get_active_participant()` ist der öffentliche Getter für den aktuell aktiven Teilnehmer.

### Aktions-Feedback ("wer tut was")

`CombatActionResult` trägt pro Ziel ein `CombatActionOutcome` (Schaden/Heilung/Ausweichen/besiegt). `CombatSession.announce_action(actor, action, result)` (Signal `action_resolved`) ist der zentrale Aufrufpunkt, den sowohl `state_combat_turn.gd` als auch `npc_combat_brain.gd` nach jeder aufgelösten Aktion aufrufen. `CombatNarrator.describe(...)` baut daraus deutsche Zeilen ("Bandit trifft Dannerman mit Messer (Stechen) – 6 Schaden"), die `CombatLogHud` (unten links) gestapelt anzeigt und einzeln ausblendet. Reden/Fliehen laufen nicht über `CombatResolver` und erscheinen aktuell nicht im Log.

### Party-Fähigkeiten außerhalb des Kampfes

Taste **F** (Input-Action `Faehigkeiten`, nur am Leader) öffnet `state_party_skills.gd`: Charakter aus der Party wählen → Fähigkeit wählen → Ziel wählen. Ziele innerhalb der Party (SELF/SINGLE_ALLY/ALL_ALLIES) wirken sofort über `PartyAbilityResolver.apply_non_combat()` (nur `HEAL` implementiert, ruft ausschließlich bestehende `Playable`-Methoden auf). Ziele außerhalb der Party (SINGLE_ENEMY/ALL_ENEMIES) werden wie im E-Menü in Reichweite gesucht (`ActionRangeIndicator`) und lösen `CombatManager.trigger_attack()` aus – die Fähigkeit wird dann als Erstschlag im neuen/erweiterten Kampf ganz regulär über `CombatResolver` aufgelöst, ohne reguläre `end_turn()`-Buchhaltung (kein zweiter Schadenscode-Pfad).

### Offene Punkte

Bewusst noch nicht entschieden (siehe Implementierungsplan): Konsequenz bei Niederlage der ganzen Party (nur `CombatSession.side_wiped`-Signal als Hook, keine Logik dahinter), Fernkampf-Reichweite über Sichtlinie hinaus, welche Magie explizit keine Sichtlinie braucht, mehrere gleichzeitige Kämpfe (aktuell: eine globale Sitzung), ob sich der "Erstschlag außerhalb der Zugreihenfolge" bei Party-Fähigkeiten gegen Fremde richtig anfühlt oder eine reguläre Zug-Einreihung besser wäre, ob die Kamera während des Kampfzugs eines Followers kurz umschalten soll (aktuell: nein, bleibt beim Leader).

---

## Hauptmenü

### Übersicht

Das Hauptmenü ist im Final Fantasy-Stil mit:
1. Logo-Einblendungen (überspringbar)
2. Intro-Text (scrollt von unten nach oben)
3. Hauptmenü mit Buttons

### Dateien

| Datei | Beschreibung |
|-------|--------------|
| `src/ui/menus/MainMenu.tscn` | Hauptszene |
| `src/ui/menus/MainMenu.gd` | Steuerungslogik |

### Parameter (MainMenu.gd)

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `logo_display_time` | float | 2.0 | Anzeigedauer pro Logo |
| `logo_fade_time` | float | 1.0 | Ein-/Ausblendzeit |
| `intro_scroll_speed` | float | 30.0 | Scroll-Geschwindigkeit |
| `game_scene_path` | String | "res://src/core/main_game/main_game.tscn" | Spielszene |

### Anpassen

#### Logos ändern

1. `LogosContainer/Logo1` und `Logo2` sind TextureRect Nodes
2. Ersetze die Label-Kinder durch eigene Texturen
3. Oder ändere den Text in `Logo1Text` / `Logo2Text`

#### Intro-Text ändern

1. Öffne `MainMenu.tscn`
2. Wähle `IntroContainer/IntroText`
3. Ändere den `text` im Inspector

#### Buttons hinzufügen

```gdscript
# In MainMenu.gd

@onready var options_button: Button = $MainMenuContainer/VBoxContainer/OptionsButton

func _ready():
    # ... existing code ...
    options_button.pressed.connect(_on_options_pressed)

func _on_options_pressed():
    # Options-Menü öffnen
    pass
```

### Ablauf

```
┌─────────────────────────────────────────┐
│           MenuState.LOGOS               │
│  ┌─────────────────────────────────┐    │
│  │ Fade aus Schwarz                │    │
│  │ Logo 1: ein → warten → aus      │    │
│  │ Logo 2: ein → warten → aus      │    │
│  └─────────────────────────────────┘    │
│              ↓ (oder Skip)              │
├─────────────────────────────────────────┤
│           MenuState.INTRO               │
│  ┌─────────────────────────────────┐    │
│  │ Text scrollt von unten nach oben│    │
│  └─────────────────────────────────┘    │
│              ↓ (oder Skip)              │
├─────────────────────────────────────────┤
│         MenuState.MAIN_MENU             │
│  ┌─────────────────────────────────┐    │
│  │ Titel einblenden                │    │
│  │ Buttons einblenden              │    │
│  │ Warten auf Eingabe              │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

---

## Tipps & Best Practices

### Performance

- Schrittgeräusche verwenden Raycast nur beim Abspielen, nicht jeden Frame
- Kamera-Interpolation verhindert ruckelige Bewegungen
- State Machine vermeidet komplexe if/else Ketten

### Erweiterbarkeit

- Neue Oberflächentypen: `SurfaceType.gd` erweitern
- Neue States: Neues Script erstellen, das `State` erweitert
- Neue Sounds: Einfach zur FootstepSounds Resource hinzufügen

### Debugging

```gdscript
# Aktuelle Oberfläche ausgeben:
footstep_player.footstep_played.connect(func(type):
    print("Surface: ", SurfaceType.to_string_name(type))
)

# Aktuellen State ausgeben:
print(state_machine.current_state.name)
```

---

## Changelog

### Nach 0.1 Alpha

- Player-X-Ray hinter Wänden: `OcclusionVisual` + Depth-Zweitpass, ohne z_index-Tricks
- Dialogkamera: Events `shot_changed` / `transition_finished` / `control_returned` am `CameraSystem.events`
- Dialogkamera: Shot-FOV und Transition (`DialogueCameraMarker.fov` / `transition_sec` / `transition_ease`), parallel zum Position-Tween
- Dialogkamera: Shot-Tags und Gewichte für `RANDOM` (`shots=emotional`, `DialogueCameraMarker.weight`/`tags`)
- Dialogkamera: Look-Targets (`Eyes`/`Head`/`Mouth`) getrennt von Shot-Position; Tags `[#look=eyes]`
- Dialogkamera: `CameraSystem` fährt Shots über `DialogueCameraPoints` / `Marker3D`; Dialogue-Manager-Tags `[#camera=…]`
- Input-Aktion `Attack` → `Interact` (Semantik: Umwelt & Objekte, kein Echtzeit-Schlag)
- Shalka-State-Machine: Echtzeit-`Attack`-State entfernt; Fokus auf Exploration + Kontextmenü

### Version 0.1 Alpha

- 2D zu 2.5D Konvertierung
- Billboard Sprites
- Mode7-Kamera mit goldenem Schnitt
- Sprint-System mit Anlaufzeit
- Schrittgeräusche-System
- Final Fantasy-Stil Hauptmenü
