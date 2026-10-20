class_name MusicSystem
extends Node

## Levelmusik bleibt pausiert an ihrer Position; Gegnerbedrohungen überleben
## das Ende einer Kampfsitzung nach Party-Flucht, niemals einen Levelwechsel.
@export_range(0.05, 2.0) var fade_seconds: float = 0.35
@export var normal_music_path := "res://assets/audio/music/boss_battle.mp3"
@export var boss_music_path := "res://assets/audio/music/boss_battle.mp3"
@export var superboss_music_path := "res://assets/audio/music/boss_battle.mp3"
@export var final_music_path := "res://assets/audio/music/boss_battle.mp3"
@export var active_volume_db: float = -6.0
@export var lingering_volume_db: float = -14.0

var level_player: AudioStreamPlayer
var battle_players: Array[AudioStreamPlayer] = []
var level_resume_position: float = 0.0
var _threats: Array[CombatParticipant] = []
var _level_path := ""
var _battle_path := ""
var _battle_index := 0
var _mode := ""
var _fade: Tween
var _manager: CombatManager
var _levels: LevelManager


func _ready() -> void:
	level_player = _make_player("LevelMusic")
	battle_players = [_make_player("BattleMusicA"), _make_player("BattleMusicB")]
	_manager = get_parent().get_node_or_null("CombatManager") as CombatManager
	_levels = get_parent().get_node_or_null("LevelManager") as LevelManager
	if _manager:
		_manager.combat_started.connect(_on_combat_started)
		_manager.combat_ended.connect(_on_combat_ended)
	if _levels:
		_levels.level_loaded.connect(_on_level_loaded)
		_levels.level_unloaded.connect(_on_level_unloaded)


func _make_player(label: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.volume_db = -80.0
	if AudioServer.get_bus_index("Music") >= 0:
		player.bus = &"Music"
	add_child(player)
	return player


func _exit_tree() -> void:
	if _fade:
		_fade.kill()


func _stream(path: String, loop: bool) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var source := load(path) as AudioStream
	if source == null:
		return null
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	return stream


func _on_level_loaded(level: BaseLevel) -> void:
	_threats.clear()
	_level_path = level.music_path
	level_resume_position = 0.0
	# Auch zwischen zwei Levels bleibt das alte Stück bis zum Fade hörbar.
	if level_player.playing and not level_player.stream_paused:
		var outgoing := battle_players[1 - _battle_index]
		outgoing.stop()
		outgoing.stream = level_player.stream
		outgoing.volume_db = level_player.volume_db
		outgoing.play(level_player.get_playback_position())
	level_player.stop()
	level_player.stream = _stream(_level_path, level.music_loop)
	level_player.stream_paused = false
	level_player.volume_db = -80.0
	if level_player.stream:
		level_player.play()
	_mode = ""
	_refresh()


func _on_level_unloaded(_path: String) -> void:
	_threats.clear()
	_level_path = ""
	_mode = ""
	_transition("silence", "")


func _on_combat_started(session: CombatSession) -> void:
	session.participant_joined.connect(_on_participant_joined.bind(session))


func _on_participant_joined(_participant: CombatParticipant, session: CombatSession) -> void:
	# Eine Seite ist erst nach Aufnahme von Angreifer UND Opfer erkennbar.
	var party_sides: Array[StringName] = []
	for participant in session.participants:
		if is_instance_valid(participant.playable) and _is_party_member(participant.playable):
			if not party_sides.has(participant.side):
				party_sides.append(participant.side)
	if party_sides.is_empty():
		return
	for participant in session.participants:
		if not is_instance_valid(participant.playable) or _is_party_member(participant.playable) or party_sides.has(participant.side):
			continue
		# Eine neue Sitzung kann dieselbe überlebende Figur erneut aufnehmen.
		for i in range(_threats.size() - 1, -1, -1):
			if _threats[i].playable == participant.playable:
				_threats.remove_at(i)
		_threats.append(participant)
	_refresh()


func _is_party_member(playable: Playable) -> bool:
	var ancestor: Node = playable.get_parent()
	while ancestor:
		if ancestor is Party:
			return true
		ancestor = ancestor.get_parent()
	return false


func _on_combat_ended(_session: CombatSession, _outcome: Dictionary) -> void:
	_refresh()


func _process(_delta: float) -> void:
	if level_player:
		_refresh()


func _refresh() -> void:
	var category := -1
	var active := false
	for i in range(_threats.size() - 1, -1, -1):
		var participant := _threats[i]
		var playable := participant.playable
		if not is_instance_valid(playable) or participant.is_defeated or playable.is_character_dead() or playable.character.is_defeated or (participant.has_fled and playable.flee_path.is_empty()):
			_threats.remove_at(i)
			continue
		var value: int = playable.battle_music_category if playable is NPC else 0
		category = maxi(category, value)
		if _manager and _manager.active_session and _manager.active_session.get_participant(playable) != null:
			active = true
	if category < 0:
		_transition("level" if not _level_path.is_empty() else "silence", "")
	else:
		var paths := [normal_music_path, boss_music_path, superboss_music_path, final_music_path]
		_transition("battle" if active else "lingering", paths[clampi(category, 0, 3)])


func _transition(mode: String, path: String) -> void:
	if mode == _mode and path == _battle_path:
		return
	_mode = mode
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	var battle := mode in ["battle", "lingering"]
	if battle and path != _battle_path:
		_battle_index = 1 - _battle_index
		var incoming := battle_players[_battle_index]
		incoming.stop()
		incoming.stream = _stream(path, true)
		incoming.volume_db = -80.0
		if incoming.stream:
			incoming.play()
	_battle_path = path
	if not battle and mode == "level" and level_player.stream:
		# Pausieren erhält die exakte Position, auch für einmalige Lieder.
		level_player.stream_paused = false
	var level_volume := active_volume_db if mode == "level" else -80.0
	_fade.tween_property(level_player, "volume_db", level_volume, fade_seconds)
	for i in battle_players.size():
		var player := battle_players[i]
		var volume := (active_volume_db if mode == "battle" else lingering_volume_db) if battle and i == _battle_index else -80.0
		_fade.tween_property(player, "volume_db", volume, fade_seconds)
	_fade.chain().tween_callback(_finish_fade.bind(mode))


func _finish_fade(mode: String) -> void:
	if mode != "level":
		if level_player.playing:
			level_resume_position = level_player.get_playback_position()
		level_player.stream_paused = true
	for i in battle_players.size():
		if mode not in ["battle", "lingering"] or i != _battle_index:
			battle_players[i].stop()
