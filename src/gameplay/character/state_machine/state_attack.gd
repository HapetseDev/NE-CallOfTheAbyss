class_name StateAttack extends State

var attacking: bool = false

@export var attack_sound: AudioStream
@export_range(1, 20, 0.5) var decelerate_speed: float = 5.0

@onready var idle: State = $"../Idle"
@onready var walk: State = $"../Walk"
@onready var animation_player: AnimationPlayer = $"../../AnimationPlayer"
@onready var e_effect_anim_player: AnimationPlayer = $"../../Sprite3D/E-Effect/E-EffecctAnimPlayer"
@onready var audio_player: AudioStreamPlayer3D = $"../../Audio/AudioStreamPlayer3D"
@onready var hurt_box: HurtBox = %AttackHurtBox


func enter() -> void:
	player.update_animation("attack")
	e_effect_anim_player.play("attack_" + player.anim_direction())
	animation_player.animation_finished.connect(end_attack)
	audio_player.stream = attack_sound
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()
	attacking = true
	await get_tree().create_timer(0.075).timeout
	hurt_box.monitoring = true


func exit() -> void:
	animation_player.animation_finished.disconnect(end_attack)
	attacking = false
	hurt_box.monitoring = false


func process(_delta: float) -> State:
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	horizontal -= horizontal * decelerate_speed * _delta
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	if not attacking:
		return walk if player.direction != Vector3.ZERO else idle
	return null


func end_attack(_new_anim_name: String) -> void:
	attacking = false
