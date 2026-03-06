class_name StateAttack extends State

var attacking : bool = false

@export var attack_sound : AudioStream
@export_range(1,20,0.5) var decelerateSpeed : float = 5.0

@onready var idle: State = $"../Idle"

@onready var walk: State = $"../Walk"
@onready var animation_player: AnimationPlayer = $"../../AnimationPlayer"
@onready var e_effecct_anim_player: AnimationPlayer = $"../../Sprite3D/E-Effect/E-EffecctAnimPlayer"
@onready var audioPlayer: AudioStreamPlayer3D = $"../../Audio/AudioStreamPlayer3D"
@onready var hurt_box: HurtBox = %AttackHurtBox

# Was passiert, wenn der State betreten wird?
func Enter() -> void:
	player.UpdateAnimation("attack")
	e_effecct_anim_player.play("attack_" + player.AnimDirection())
	animation_player.animation_finished.connect( EndAttack)
	audioPlayer.stream = attack_sound
	audioPlayer.pitch_scale = randf_range(0.9,1.1)
	audioPlayer.play()
	attacking = true
	await get_tree().create_timer(0.075).timeout
	hurt_box.monitoring = true
	pass

# Was passiert beim Verlassen des States?
func Exit() -> void:
	animation_player.animation_finished.disconnect( EndAttack)
	attacking = false
	hurt_box.monitoring = false
	pass

# Was passiert beim _process Update?
func Process(_delta: float) -> State:
	player.velocity -= player.velocity * decelerateSpeed * _delta
	if attacking == false:
		if player.direction == Vector3.ZERO:
			return idle
		else:
			return walk
	return null

# Was passiert im _physics Prozess in diesem State?
func Physics(_delta: float) -> State:
	return null

# Was passiert mit input Events in diesem State?
func HandleInput(_event: InputEvent) -> State:
	return null

func EndAttack( _newAnimName : String) -> void:
	attacking = false
