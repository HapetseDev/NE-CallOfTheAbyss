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
7. [Hauptmenü](#hauptmenü)

---

## Projektstruktur

```
NECOTA2D/
├── Charaktere/
│   ├── player.gd                 # Basis-Spielerklasse
│   ├── Props/Fauna/
│   │   ├── Plant.tscn            # Zerstörbare Pflanze
│   │   └── plant.gd
│   └── SPC/Shalka/
│       ├── shalka.tscn           # Hauptcharakter-Szene
│       ├── shalka.gd             # Shalka-spezifische Logik
│       └── playerInteractonHost.gd
├── Generic/
│   ├── Hitbox/                   # Schadens-Empfänger
│   └── Hurtbox/                  # Schadens-Verursacher
├── Scripts/
│   ├── PlayerCamera.gd           # Kamera mit Mode7-Effekt
│   ├── playerStateMachine.gd     # State Machine Controller
│   ├── stateIdle.gd              # Idle State
│   ├── stateWalk.gd              # Walk State mit Sprint
│   ├── stateActionMenu.gd        # Kontextmenü (Objekte, später Dialoge)
│   └── stateAttack.gd            # (Archiv) Echtzeit-Schlag — nicht an Shalka-FSM angebunden
├── Systems/
│   └── Footsteps/                # Schrittgeräusche-System
├── UI/
│   └── MainMenu/                 # Hauptmenü (FF-Stil)
├── Maps/
│   └── Level1Ep1.tscn            # Haupt-Level
└── Globals/
    └── GlobalLevelManager.gd     # Globaler Level-Manager
```

---

## Schrittgeräusche-System

### Übersicht

Das System erkennt automatisch die Oberfläche unter dem Charakter und spielt passende Schrittgeräusche ab.

### Dateien

| Datei | Beschreibung |
|-------|--------------|
| `Systems/Footsteps/SurfaceType.gd` | Enum für Oberflächentypen |
| `Systems/Footsteps/FootstepSounds.gd` | Resource für Sound-Bibliotheken |
| `Systems/Footsteps/FootstepPlayer.gd` | Hauptkomponente |
| `Systems/Footsteps/SurfaceDefinition.gd` | Helper für Oberflächen |
| `Systems/Footsteps/DefaultFootsteps.tres` | Beispiel-Resource |

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

Die Kamera hat einen Mode7-ähnlichen schrägen Blickwinkel und positioniert sich basierend auf der Blickrichtung des Spielers (Goldener Schnitt).

### Parameter (PlayerCamera.gd)

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `follow_distance` | float | 8.0 | Abstand hinter dem Spieler |
| `camera_height` | float | 6.0 | Höhe über dem Spieler |
| `pitch_angle` | float | -45.0 | Neigungswinkel (Mode7: -30 bis -60) |
| `smooth_speed` | float | 5.0 | Glättung der Bewegung |
| `look_ahead_distance` | float | 3.0 | Vorausschau in Blickrichtung |

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

Erkundung nutzt die State Machine für **Bewegung** und **Interaktion** (Kontextmenü). **Kampf** ist für später als **rundenbasiert** vorgesehen (eigene Szene oder Modus), nicht als Echtzeit-Angriff in Idle/Walk.

### Struktur (Shalka)

```
StateMachine (Node)
├── Idle (Node) → stateIdle.gd
├── Walk (Node) → stateWalk.gd
└── ActionMenu (Node) → stateActionMenu.gd
```

Das Script `stateAttack.gd` bleibt im Projekt, ist aber **nicht** als Kind der Shalka-State-Machine eingebunden (kein Action-Kampf als Standard).

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

## Hauptmenü

### Übersicht

Das Hauptmenü ist im Final Fantasy-Stil mit:
1. Logo-Einblendungen (überspringbar)
2. Intro-Text (scrollt von unten nach oben)
3. Hauptmenü mit Buttons

### Dateien

| Datei | Beschreibung |
|-------|--------------|
| `UI/MainMenu/MainMenu.tscn` | Hauptszene |
| `UI/MainMenu/MainMenu.gd` | Steuerungslogik |

### Parameter (MainMenu.gd)

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `logo_display_time` | float | 2.0 | Anzeigedauer pro Logo |
| `logo_fade_time` | float | 1.0 | Ein-/Ausblendzeit |
| `intro_scroll_speed` | float | 30.0 | Scroll-Geschwindigkeit |
| `game_scene_path` | String | "res://Maps/Level1Ep1.tscn" | Spielszene |

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

- Input-Aktion `Attack` → `Interact` (Semantik: Umwelt & Objekte, kein Echtzeit-Schlag)
- Shalka-State-Machine: Echtzeit-`Attack`-State entfernt; Fokus auf Exploration + Kontextmenü

### Version 0.1 Alpha

- 2D zu 2.5D Konvertierung
- Billboard Sprites
- Mode7-Kamera mit goldenem Schnitt
- Sprint-System mit Anlaufzeit
- Schrittgeräusche-System
- Final Fantasy-Stil Hauptmenü
