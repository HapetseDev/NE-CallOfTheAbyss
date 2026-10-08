class_name DialogueSystem
extends Node

## Spiel-Dialog unter MainGame/Systems.
## Das Addon-Autoload DialogueManager bleibt, weil das Plugin es braucht.
## Vollbildgespräche verwenden eine eigene UI; die Kamera-Signale bleiben für
## explizite Inszenierung und die Rückkehr zur Spielkamera verfügbar.

static var instance: DialogueSystem

signal dialogue_started
signal dialogue_line_changed(subject: Node3D, shot: CameraShot.Kind, look_target: Node3D, look: CameraShot.Look, shot_tags: PackedStringArray)
signal dialogue_ended

var _current_player: Playable
var _active_balloon: Node
var _active_npc: NPC
var _session_active: bool = false
## Das Addon ergänzt diesen Kontext um eine Referenz auf die Dialogresource.
## Beim Abbruch leeren, damit kein alter Sitzungskontext erhalten bleibt.
var _dialogue_game_states: Array = []
var _has_applied_shot: bool = false
var current_data: NPCData
var _lock_owned := false
const CONVERSATION_UI := preload("res://src/ui/dialogue/conversation_ui.gd")


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	finish_conversation()
	_dialogue_game_states.clear()
	if instance == self:
		instance = null


func _ready() -> void:
	if not DialogueManager.got_dialogue.is_connected(_on_got_dialogue):
		DialogueManager.got_dialogue.connect(_on_got_dialogue)
	if CombatManager.instance:
		CombatManager.instance.combat_started.connect(_on_combat_started)


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
	if not _session_active or not is_instance_valid(_current_player) or current_data == null:
		return
	if not current_data.can_trade or shop_id != current_data.shop_id or _npc_defeated():
		return
	var player := _current_player
	finish_conversation()
	ShopManager.open(shop_id, player)


## Dialog-Mutation "do start_encounter(...)" – Signatur bleibt für bestehende
## .dialogue-Dateien kompatibel, encounter_id wird aber nicht mehr genutzt:
## die neue Kampf-Engine ermittelt Teilnehmer dynamisch (CombatParticipantResolver)
## statt aus einer festen Encounter-Gegnerliste. Greift den aktiven Dialog-NPC an.
func start_encounter(_encounter_id: String) -> void:
	var player := get_current_player()
	var npc := get_active_npc()
	if not _session_active or not is_instance_valid(player) or npc == null or _npc_defeated():
		return
	finish_conversation()
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
	if data == null or not is_instance_valid(player) or _session_active:
		return
	if GameState.is_player_input_locked():
		return
	var resource := load(data.dialogue_file) as DialogueResource
	if resource == null or resource.lines.is_empty():
		push_warning("DialogueSystem: Dialog konnte nicht geladen werden: " + data.dialogue_file)
		return
	var start_cue := _resolve_start_cue(data)
	if not resource.titles.has(start_cue):
		push_warning("DialogueSystem: Dialogtitel fehlt: " + start_cue)
		return
	_current_player = player
	current_data = data
	_active_npc = _get_npc_from_interaction(source)
	if _active_npc:
		_active_npc.begin_dialogue_facing(player)
	GameState.acquire_input_lock()
	_lock_owned = true
	_session_active = true
	_has_applied_shot = false
	_dialogue_game_states = [{"player": player}, self, player, GameState]
	_active_balloon = CONVERSATION_UI.new()
	_active_balloon.system = self
	MainGame.instance.dialogue_root.add_child(_active_balloon)
	_active_balloon.tree_exiting.connect(_on_window_exiting.bind(_active_balloon), CONNECT_ONE_SHOT)
	dialogue_started.emit()
	_active_balloon.start(resource, start_cue, _dialogue_game_states)


## END kehrt zur Themenwahl zurück; erst explizites Schließen beendet die Sitzung.
func finish_conversation() -> void:
	if not _session_active:
		return
	_session_active = false
	var window := _active_balloon
	_active_balloon = null
	if is_instance_valid(window):
		window.dismiss()
	_dialogue_game_states.clear()
	_has_applied_shot = false
	_restore_dialogue_npc_facing()
	_current_player = null
	current_data = null
	if _lock_owned:
		GameState.release_input_lock()
		_lock_owned = false
	dialogue_ended.emit()


func _on_window_exiting(window: Node) -> void:
	_release_balloon_context(window)
	if window == _active_balloon:
		finish_conversation()


func _release_balloon_context(balloon: Node) -> void:
	# Die Gesprächsansicht erstellt eine eigene Kontextliste. Das Addon kann
	# diese in der Dialogresource referenzieren; beim Schließen den Zyklus lösen.
	if "temporary_game_states" in balloon:
		var context: Variant = balloon.get("temporary_game_states")
		if context is Array:
			context.clear()
	# get_line() im Addon legt data.resource = resource direkt in lines ab.
	# Diese Laufzeit-Selbstreferenzen überleben sonst selbst den Szenenabbau.
	if "dialogue_resource" in balloon:
		var resource := balloon.get("dialogue_resource") as DialogueResource
		if resource:
			for line: Dictionary in resource.lines.values():
				if line.get("resource") == resource:
					line.erase("resource")




func _on_got_dialogue(line: DialogueLine) -> void:
	if not _session_active or line == null:
		return
	if line.type != DMConstants.TYPE_DIALOGUE:
		return
	_log_dialogue_line(line)
	# Vollbildgespräche benötigen keinen Wechsel der Weltkamera.


## Dialogzeilen landen ebenfalls im projektweiten EventLog (EventLogHud) –
## line.text kann BBCode enthalten (Dialogue Manager erlaubt z.B. [wave]),
## das für die Log-Zeile entfernt wird.
func _log_dialogue_line(line: DialogueLine) -> void:
	var speaker := line.character.strip_edges()
	var text := _strip_bbcode(line.text)
	if text.is_empty():
		return
	if speaker.is_empty():
		EventLog.add(text)
	else:
		EventLog.add("%s: %s" % [speaker, text])


func _strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[[^\\]]*\\]")
	return regex.sub(text, "", true).strip_edges()


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
		var active_npc := get_active_npc()
		if active_npc:
			return active_npc
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
		if GameState.world_state.get_quest_state("bandit") == "ready":
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


func _npc_defeated() -> bool:
	var npc := get_active_npc()
	return npc != null and npc.character != null and npc.character.is_defeated


## Stabile IDs per [#subject=...] sind bei gleichen Anzeigenamen eindeutig.
func speaker_for(key: String) -> Dictionary:
	var normalized := key.strip_edges().to_lower()
	var members: Array[Playable] = MainGame.instance.party.get_all_members() if MainGame.instance and MainGame.instance.party else [] as Array[Playable]
	var who: Playable
	if normalized in ["player", "spieler"]:
		who = _current_player
	elif normalized == "npc":
		who = get_active_npc()
	else:
		# Hauptgesprächspartner hat bei mehrdeutigen NPC-Namen Vorrang.
		if _matches_speaker(get_active_npc(), key):
			who = get_active_npc()
		for member in members:
			if _matches_speaker(member, key):
				who = member
		if who == null:
			for node in get_tree().get_nodes_in_group("combat_reactive"):
				if node is Playable and _matches_speaker(node, key):
					who = node
					break
	if is_instance_valid(who):
		var picture: Texture2D = who.character.get_portrait() if who.character else null
		if who is NPC:
			var interaction := who.get_node_or_null("Interaction") as NPCInteraction
			if interaction and interaction.data and interaction.data.portrait:
				picture = interaction.data.portrait
		return {"name": who.get_display_name(), "party": who in members, "portrait": picture}
	if normalized == "npc" and current_data:
		return {"name": current_data.display_name, "party": false, "portrait": current_data.portrait}
	# Auch nicht instanziierte, registrierte Gäste können ihren Beitrag leisten.
	var character := GameState.character_registry.get_character(key)
	if character:
		return {"name": character.character_name, "party": false, "portrait": character.get_portrait()}
	return {"name": key, "party": false, "portrait": null}


func _matches_speaker(who: Playable, key: String) -> bool:
	return is_instance_valid(who) and (		(who.character != null and who.character.character_id.nocasecmp_to(key) == 0) or _matches_playable(who, key))


func conversation_options(resource: DialogueResource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current_data == null or not is_instance_valid(_current_player):
		return result
	if current_data.can_trade and not current_data.shop_id.is_empty() and not _npc_defeated():
		result.append({"label": "Handeln", "action": "trade"})
	for topic in current_data.dialogue_topics:
		if topic == null or topic.label.strip_edges().is_empty() or not resource.titles.has(topic.title):
			continue
		if not topic.required_fact_id.is_empty() and not GameState.knows_fact(_current_player.character.character_id, topic.required_fact_id):
			continue
		result.append({"label": topic.label, "title": topic.title})
	if current_data.can_fight and not _npc_defeated():
		result.append({"label": "Angreifen", "action": "fight"})
	return result


func _on_combat_started(_session: CombatSession) -> void:
	finish_conversation()
