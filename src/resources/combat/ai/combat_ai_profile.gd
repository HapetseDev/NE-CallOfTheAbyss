extends Resource

@export var behavior_tree: Resource
@export_range(1.0, 30.0) var perception_radius: float = 8.0
@export_range(0.5, 1.0) var preferred_reach_ratio: float = 0.8
@export_range(0.0, 10.0) var damage_weight: float = 1.0
@export_range(0.0, 10.0) var hostility_weight: float = 0.1
@export_range(0.0, 10.0) var wounded_target_weight: float = 2.0
@export_range(1.0, 8.0) var movement_search_radius: float = 6.0
## Mehrzügige Wegvorausschau; erweitert nicht das tatsächliche Bewegungsbudget.
@export_range(2.0, 20.0) var approach_planning_distance: float = 12.0
@export_range(0, 6) var target_memory_turns: int = 3
## Kompatibilität mit früheren Profilen; das Raster berechnet alle erreichbaren Wege gemeinsam.
@export_range(1, 8) var max_path_candidates: int = 3
@export_range(1, 8) var max_targets: int = 3
@export_range(0.05, 1.0) var minimum_progress: float = 0.15

## Einen verfügbaren Angriff nur für einen deutlich besseren Folgeangriff aufgeben.
@export var tactical_reposition_enabled: bool = true
@export_range(1.0, 4.0) var reposition_attack_multiplier: float = 2.0
@export_range(0.0, 20.0) var reposition_min_gain: float = 3.0
@export_range(0.0, 5.0) var reposition_path_cost: float = 0.5
@export_range(1, 3) var reposition_cooldown_turns: int = 1
