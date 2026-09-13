@tool
extends Node3D

signal level_modified

const ChannelSystemScript = preload("res://shared/editor_core/scripting/channel_system.gd")

@export_group("Level Info")
@export var level_name: String = "Untitled Level"
@export var level_author: String = ""
@export_multiline var level_description: String = ""
@export var level_tags: Array[String] = []
@export_group("Settings")
@export var grid_size: float = 1.0
@export var default_theme: String = "default"
@export var module_connections: Array[Dictionary] = []
@export var channel_data: Dictionary = {}

# Session state is deliberately not part of the saved document.
var authoring_mode: bool = false
var runtime_player: Node3D
var _channel_system: ChannelSystem


func _init() -> void:
	# Construct before descendant _ready callbacks request the document service.
	get_channel_system()


func _ready() -> void:
	add_to_group("level_root")
	if channel_data.is_empty():
		_bind_actors(self, get_channel_system())
	else:
		restore_runtime_bindings()
	if authoring_mode:
		freeze_authoring()


func freeze_authoring() -> void:
	_freeze_node(self)


func _freeze_node(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child: Node in node.get_children():
		_freeze_node(child)


func get_channel_system() -> ChannelSystem:
	if not is_instance_valid(_channel_system):
		_channel_system = ChannelSystemScript.new()
		_channel_system.name = "ChannelSystem"
		_channel_system.set_meta("editor_runtime_only", true)
		add_child(_channel_system)
		_channel_system.document_root = self
	return _channel_system


func restore_runtime_bindings() -> void:
	var system := get_channel_system()
	system.deserialize(channel_data, self)
	_bind_actors(self, system)


func get_actor_identity(actor: Node) -> String:
	return get_channel_system().get_binding_id(actor)


func find_actor(identity: String) -> Node:
	return get_channel_system().find_actor(identity)


func _bind_actors(node: Node, system: ChannelSystem) -> void:
	if node is ActorBase:
		system.get_binding_id(node)
		if not node.output_channel.is_empty():
			system.connect_source(node, node.output_channel)
		for channel: String in node.input_channels:
			system.connect_target(node, channel)
	for child: Node in node.get_children():
		if not child.get_meta("editor_runtime_only", false):
			_bind_actors(child, system)


func prepare_for_save() -> void:
	var system := get_channel_system()
	_bind_actors(self, system)
	channel_data = system.serialize()
	prepare_ownership(self, self)


static func prepare_ownership(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		if root == null or child.get_meta("editor_runtime_only", false):
			child.owner = null
			prepare_ownership(child, null)
			continue
		if child.owner == null or (child.owner != root and not root.is_ancestor_of(child.owner)):
			child.owner = root
		prepare_ownership(child, root)


func get_spawn_points(spawn_type: String = "") -> Array[Node3D]:
	var points: Array[Node3D] = []
	_collect_spawn_points(self, spawn_type, points)
	return points


func _collect_spawn_points(node: Node, spawn_type: String, points: Array[Node3D]) -> void:
	for child: Node in node.get_children():
		if child.get_meta("editor_runtime_only", false):
			continue
		if child is Node3D and child.has_method("get_spawn_type"):
			if spawn_type.is_empty() or child.get_spawn_type() == spawn_type:
				points.append(child)
		_collect_spawn_points(child, spawn_type, points)


func validate_level() -> Dictionary:
	var result := {"valid": true, "errors": [], "warnings": []}
	if get_spawn_points("player").is_empty():
		result.valid = false
		result.errors.append("No player spawn point found")
	if level_name.is_empty() or level_name == "Untitled Level":
		result.warnings.append("Level has default name")
	for channel_name: String in get_channel_system().channels:
		var channel: Dictionary = get_channel_system().channels[channel_name]
		if channel.sources.is_empty():
			result.warnings.append("Channel '%s' has no sources" % channel_name)
		if channel.targets.is_empty():
			result.warnings.append("Channel '%s' has no targets" % channel_name)
	return result


func serialize() -> Dictionary:
	prepare_for_save()
	return {
		"level_name": level_name,
		"level_author": level_author,
		"level_description": level_description,
		"level_tags": level_tags.duplicate(),
		"grid_size": grid_size,
		"default_theme": default_theme,
		"module_connections": module_connections.duplicate(true),
		"channel_data": channel_data.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	level_name = data.get("level_name", "Untitled Level")
	level_author = data.get("level_author", "")
	level_description = data.get("level_description", "")
	level_tags.assign(data.get("level_tags", []))
	grid_size = data.get("grid_size", 1.0)
	default_theme = data.get("default_theme", "default")
	module_connections.assign(data.get("module_connections", []))
	channel_data = data.get("channel_data", {}).duplicate(true)
	restore_runtime_bindings()
