class_name DialogueSystem
extends Node

## Spiel-Dialog unter MainGame/Systems.
## Das Addon-Autoload DialogueManager bleibt, weil das Plugin es braucht.
## Kamera-Wünsche gehen als Signal raus; CameraSystem bewegt die Kamera.

static var instance: DialogueSystem

signal dialogue_started
signal dialogue_line_changed(subject: Node3D, shot: CameraShot.Kind, look_target: Node3D, look: CameraShot.Look, shot_tags: PackedStringArray)
signal dialogue_ended

var _current_player: Playable
var _active_balloon: Node
var _active_npc: NPC
var _session_active: bool = false
var _has_applied_shot: bool = false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if not DialogueManager.got_dialogue.is_connected(_on_got_dialogue):
		DialogueManager.got_dialogue.connect(_on_got_dialogue)


static func start_npc_dialogue(data: NPCData, player: Playable, source: NPCInteraction = null) -> void:
	if instance == null:
		push_error("DialogueSystem: MainGame ist nicht aktiv.")
		return
	instance._start_npc_dialogue(data, player, source)


func get_current_player() -> Playable:
	return _current_player


func get_active_npc() -> NPC:
	if _active_npc and is_instance_valid(_active_npc):
		return _active_npc
	return null


func open_shop(shop_id: String) -> void:
	var player := get_current_player()
	if player == null:
		return
	ShopManager.open(shop_id, player)


## Dialog-Mutation "do start_encounter(...)" – Signatur bleibt für bestehende
## .dialogue-Dateien kompatibel, encounter_id wird aber nicht mehr genutzt:
## die neue Kampf-Engine ermittelt Teilnehmer dynamisch (CombatParticipantResolver)
## statt aus einer festen Encounter-Gegnerliste. Greift den aktiven Dialog-NPC an.
func start_encounter(_encounter_id: String) -> void:
	var player := get_current_player()
	var npc := get_active_npc()
	if player == null or npc == null:
		return
	CombatManager.trigger_attack(player, npc)


func request_shot(
	shot_name: String,
	subject_key: String = "",
	look_name: String = "",
	tags_text: String = ""
) -> void:
	if not _session_active:
		return
	var subject := _subject_from_key(subject_key)
	if subject == null:
		return
	var kind := CameraShot.parse(shot_name)
	_emit_shot(subject, kind, CameraShot.parse_look(look_name), CameraShot.split_tags(tags_text))


func _start_npc_dialogue(data: NPCData, player: Playable, source: NPCInteraction = null) -> void:
	if data == null or player == null:
		return
	_current_player = player
	_restore_dialogue_npc_facing()
	_active_npc = _get_npc_from_interaction(source)
	if _active_npc:
		_active_npc.begin_dialogue_facing(player)
	GameState.acquire_input_lock()
	var start_cue := _resolve_start_cue(data)
	var resource := load(data.dialogue_file) as DialogueResource
	if resource == null:
		push_warning("DialogueSystem: Dialog '%s' konnte nicht geladen werden." % data.dialogue_file)
		_restore_dialogue_npc_facing()
		GameState.release_input_lock()
		return
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_has_applied_shot = false
	_session_active = true
	_active_balloon = DialogueManager.show_dialogue_balloon(resource, start_cue, [self, player, GameState])
	dialogue_started.emit()


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_active_balloon = null
	_session_active = false
	_has_applied_shot = false
	_restore_dialogue_npc_facing()
	GameState.release_input_lock()
	dialogue_ended.emit()


func _on_got_dialogue(line: DialogueLine) -> void:
	if not _session_active or line == null:
		return
	if line.type != DMConstants.TYPE_DIALOGUE:
		return
	var shot_value: Variant = _shot_from_line(line)
	var kind: CameraShot.Kind
	if shot_value == null:
		if _has_applied_shot:
			return
		kind = CameraShot.Kind.MEDIUM
	else:
		kind = CameraShot.coerce(shot_value)
	var subject := _resolve_subject(line)
	if subject == null:
		return
	_emit_shot(subject, kind, _look_from_line(line), _shot_tags_from_line(line))


func _emit_shot(
	subject: Node3D,
	shot: CameraShot.Kind,
	look: CameraShot.Look = CameraShot.Look.AUTO,
	shot_tags: PackedStringArray = PackedStringArray()
) -> void:
	if subject == null or not is_instance_valid(subject):
		return
	var look_target := subject
	if shot == CameraShot.Kind.OVER_SHOULDER or shot == CameraShot.Kind.RANDOM:
		look_target = _conversation_partner(subject)
	_has_applied_shot = true
	dialogue_line_changed.emit(subject, shot, look_target, look, shot_tags)


func _shot_from_line(line: DialogueLine) -> Variant:
	var camera_value := line.get_tag_value("camera")
	if not camera_value.is_empty():
		return CameraShot.parse(camera_value)
	for kind: CameraShot.Kind in CameraShot.CONCRETE:
		if line.has_tag(CameraShot.tag_name(kind)):
			return kind
	if line.has_tag("random"):
		return CameraShot.Kind.RANDOM
	return null


func _look_from_line(line: DialogueLine) -> CameraShot.Look:
	var look_value := line.get_tag_value("look")
	if look_value.is_empty():
		look_value = line.get_tag_value("target")
	if not look_value.is_empty():
		return CameraShot.parse_look(look_value)
	var named_looks: Array[CameraShot.Look] = [
		CameraShot.Look.EYES,
		CameraShot.Look.HEAD,
		CameraShot.Look.MOUTH,
		CameraShot.Look.NONE,
	]
	for look: CameraShot.Look in named_looks:
		if line.has_tag(CameraShot.look_tag_name(look)):
			return look
	return CameraShot.Look.AUTO


func _shot_tags_from_line(line: DialogueLine) -> PackedStringArray:
	var result: PackedStringArray = []
	var keys: PackedStringArray = ["shots", "shot", "camtags", "camtag", "tags"]
	for key in keys:
		result = _merged_shot_tags(result, line.get_tag_value(key))
	for raw in line.tags:
		var tag := String(raw)
		var prefix := tag.get_slice("=", 0)
		if keys.has(prefix):
			result = _merged_shot_tags(result, tag.get_slice("=", 1))
	return result


func _merged_shot_tags(existing: PackedStringArray, text: String) -> PackedStringArray:
	if text.is_empty():
		return existing
	for part in CameraShot.split_tags(text):
		if not existing.has(part):
			existing.append(part)
	return existing


func _resolve_subject(line: DialogueLine) -> Node3D:
	var subject_tag := line.get_tag_value("subject").strip_edges().to_lower()
	if not subject_tag.is_empty():
		return _subject_from_key(subject_tag)
	var speaker := line.character.strip_edges()
	if _matches_playable(_current_player, speaker):
		return _current_player if is_instance_valid(_current_player) else null
	var npc := get_active_npc()
	if _matches_playable(npc, speaker):
		return npc
	if npc:
		return npc
	if _current_player and is_instance_valid(_current_player):
		return _current_player
	return null


func _subject_from_key(subject_key: String) -> Node3D:
	var key := subject_key.strip_edges().to_lower()
	if key.is_empty() or key == "speaker" or key == "npc":
		var npc := get_active_npc()
		if npc:
			return npc
		return _current_player if is_instance_valid(_current_player) else null
	if key == "player" or key == "spieler":
		return _current_player if is_instance_valid(_current_player) else null
	if _matches_playable(_current_player, subject_key):
		return _current_player if is_instance_valid(_current_player) else null
	var npc := get_active_npc()
	if _matches_playable(npc, subject_key):
		return npc
	return npc if npc else (_current_player if is_instance_valid(_current_player) else null)


func _conversation_partner(subject: Node3D) -> Node3D:
	var npc := get_active_npc()
	var player: Node3D = _current_player if is_instance_valid(_current_player) else null
	if subject == npc and player:
		return player
	if subject == player and npc:
		return npc
	return subject


func _matches_playable(who: Playable, speaker: String) -> bool:
	if who == null or not is_instance_valid(who) or speaker.is_empty():
		return false
	if who.get_display_name().nocasecmp_to(speaker) == 0:
		return true
	return who.name.nocasecmp_to(speaker) == 0


func _get_npc_from_interaction(source: NPCInteraction) -> NPC:
	if source == null:
		return null
	var parent := source.get_parent()
	return parent as NPC if parent is NPC else null


func _restore_dialogue_npc_facing() -> void:
	if _active_npc and is_instance_valid(_active_npc):
		_active_npc.end_dialogue_facing()
	_active_npc = null


func _resolve_start_cue(data: NPCData) -> String:
	var start_cue := data.dialogue_start if not data.dialogue_start.is_empty() else "start"
	if data.npc_id == "quest_giver_01":
		if GameState.get_flag("defeated_bandit", false) and not GameState.get_flag("quest_bandit_done", false):
			if _has_cue(data, "quest_done"):
				return "quest_done"
	if not data.defeated_flag.is_empty() and GameState.get_flag(data.defeated_flag, false):
		if _has_cue(data, "defeated"):
			return "defeated"
	return start_cue


func _has_cue(data: NPCData, cue: String) -> bool:
	var resource := load(data.dialogue_file) as DialogueResource
	if resource == null:
		return false
	return resource.titles.has(cue)
