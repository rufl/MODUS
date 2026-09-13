@tool
class_name ChannelSystem
extends Node

signal channel_emitted(channel_name: String, data: Dictionary)
signal connection_created(source: Node, target: Node, channel: String)
signal connection_removed(source: Node, target: Node, channel: String)

const CHANNEL_COLORS := {
	"default": Color(0.3, 0.7, 0.3),
	"trigger": Color(0.9, 0.6, 0.2),
	"door": Color(0.2, 0.5, 0.9),
	"hazard": Color(0.9, 0.2, 0.2),
	"effect": Color(0.7, 0.3, 0.9),
}

var channels: Dictionary = {}
var document_root: Node


func create_channel(channel_name: String, color: Color = Color.WHITE) -> void:
	if channels.has(channel_name):
		return

	channels[channel_name] = {
		"sources": [],
		"targets": [],
		"color": color,
		"enabled": true,
		"delay": 0.0,
		"inverted": false
	}


## Delete a channel and all its connections


func delete_channel(channel_name: String) -> void:
	if not channels.has(channel_name):
		return

	var channel: Dictionary = channels[channel_name]
	for source: Node in channel.sources.duplicate():
		disconnect_node(source, channel_name)
	for target: Node in channel.targets.duplicate():
		disconnect_node(target, channel_name)

	channels.erase(channel_name)


## Connect a source node to a channel


func connect_source(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		create_channel(channel_name)
	if node is ActorBase and node.output_channel.is_empty():
		node.output_channel = channel_name

	if node not in channels[channel_name].sources:
		channels[channel_name].sources.append(node)

		# Emit connection created for each existing target
		for target: Node in channels[channel_name].targets:
			connection_created.emit(node, target, channel_name)


## Connect a target node to a channel


func connect_target(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		create_channel(channel_name)
	if node is ActorBase and channel_name not in node.input_channels:
		node.input_channels.append(channel_name)

	if node not in channels[channel_name].targets:
		channels[channel_name].targets.append(node)

		# Emit connection created for each existing source
		for source: Node in channels[channel_name].sources:
			connection_created.emit(source, node, channel_name)


## Disconnect a node from a channel


func disconnect_node(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		return

	var channel: Dictionary = channels[channel_name]
	var was_source: bool = node in channel.sources
	var was_target: bool = node in channel.targets

	channel.sources.erase(node)
	channel.targets.erase(node)
	if node is ActorBase:
		node.input_channels.erase(channel_name)
		if node.output_channel == channel_name:
			node.output_channel = ""
			for other: String in channels:
				if node in channels[other].sources:
					node.output_channel = other
					break

	# Emit removal events
	if was_source:
		for target: Node in channel.targets:
			connection_removed.emit(node, target, channel_name)
	if was_target:
		for source: Node in channel.sources:
			connection_removed.emit(source, node, channel_name)


## Create a direct connection from source to target


func create_connection(source: Node, target: Node, channel_name: String = "") -> String:
	# Auto-generate channel name if not provided
	if channel_name.is_empty():
		channel_name = "channel_%d" % channels.size()

	if not channels.has(channel_name):
		# Pick a color based on channel count
		var color_keys := CHANNEL_COLORS.keys()
		var color: Color = CHANNEL_COLORS[color_keys[channels.size() % color_keys.size()]]
		create_channel(channel_name, color)

	connect_source(source, channel_name)
	connect_target(target, channel_name)

	return channel_name


## Emit a channel event (called by sources at runtime)


func emit_from(source: Node, value: bool, data: Dictionary) -> void:
	var payload := data.duplicate()
	payload["value"] = value
	payload["source"] = data.get("source", source)
	for channel_name: String in channels.keys():
		if source in channels[channel_name].sources:
			emit(channel_name, payload)


func emit(channel_name: String, data: Dictionary = {}) -> void:
	if not channels.has(channel_name):
		return

	var channel: Dictionary = channels[channel_name]
	if not channel.enabled:
		return

	channel_emitted.emit(channel_name, data)

	# Apply delay if configured
	if channel.delay > 0:
		await get_tree().create_timer(channel.delay).timeout

	# Trigger targets
	var trigger_value: bool = bool(data.get("value", true)) != bool(channel.inverted)
	for target: Node in channel.targets:
		if is_instance_valid(target):
			_trigger_target(target, channel_name, data, trigger_value)


func _trigger_target(target: Node, channel_name: String, data: Dictionary, value: bool) -> void:
	var payload := data.duplicate()
	payload["value"] = value
	if target is ActorBase:
		target.receive_channel_input(channel_name, payload)
		return
	# Try various callback methods
	if target.has_method("on_channel_triggered"):
		target.on_channel_triggered(channel_name, payload, value)
	elif target.has_method("trigger"):
		target.trigger()
	elif target.has_method("activate"):
		target.activate()
	elif target.has_method("toggle"):
		target.toggle()
	# Handle common interactables
	elif target.has_method("open_door"):
		if value:
			target.open_door()
		else:
			target.close_door()


## Get all channels a node is connected to


func get_node_channels(node: Node) -> Array[String]:
	var result: Array[String] = []

	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]
		if node in channel.sources or node in channel.targets:
			result.append(channel_name)

	return result


## Get all connections for a node (for inspector/gizmo)


func get_node_connections(node: Node) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []

	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]

		if node in channel.sources:
			for target: Node in channel.targets:
				connections.append(
					{
						"channel": channel_name,
						"role": "source",
						"other": target,
						"color": channel.color
					}
				)

		if node in channel.targets:
			for source: Node in channel.sources:
				connections.append(
					{
						"channel": channel_name,
						"role": "target",
						"other": source,
						"color": channel.color
					}
				)

	return connections


## Set channel properties


func set_channel_enabled(channel_name: String, enabled: bool) -> void:
	if channels.has(channel_name):
		channels[channel_name].enabled = enabled


func set_channel_delay(channel_name: String, delay: float) -> void:
	if channels.has(channel_name):
		channels[channel_name].delay = maxf(0, delay)


func set_channel_inverted(channel_name: String, inverted: bool) -> void:
	if channels.has(channel_name):
		channels[channel_name].inverted = inverted


func set_channel_color(channel_name: String, color: Color) -> void:
	if channels.has(channel_name):
		channels[channel_name].color = color


func get_channel_color(channel_name: String) -> Color:
	return channels[channel_name].color if channels.has(channel_name) else Color.WHITE


## Serialize all channels to dictionary


func serialize() -> Dictionary:
	var data := {}
	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]
		data[channel_name] = {
			"sources": _ids_from_nodes(channel.sources),
			"targets": _ids_from_nodes(channel.targets),
			"color": channel.color.to_html(),
			"enabled": channel.enabled,
			"delay": channel.delay,
			"inverted": channel.inverted
		}
	return data


func deserialize(data: Dictionary, root_node: Node) -> void:
	document_root = root_node
	channels.clear()
	_clear_actor_channels(document_root)
	for channel_name: String in data:
		var saved: Dictionary = data[channel_name]
		channels[channel_name] = {
			"sources": _nodes_from_ids(saved.get("sources", [])),
			"targets": _nodes_from_ids(saved.get("targets", [])),
			"color": Color.html(saved.get("color", "ffffff")),
			"enabled": saved.get("enabled", true),
			"delay": saved.get("delay", 0.0),
			"inverted": saved.get("inverted", false)
		}
		for source: Node in channels[channel_name].sources:
			if source is ActorBase:
				source.output_channel = channel_name
		for target: Node in channels[channel_name].targets:
			if target is ActorBase and channel_name not in target.input_channels:
				target.input_channels.append(channel_name)


func _clear_actor_channels(node: Node) -> void:
	for child: Node in node.get_children():
		if child.get_meta("editor_runtime_only", false):
			continue
		if child is ActorBase:
			child.output_channel = ""
			child.input_channels = PackedStringArray()
		_clear_actor_channels(child)


func get_binding_id(node: Node) -> String:
	if not is_instance_valid(node) or not is_instance_valid(document_root):
		return ""
	if not document_root.is_ancestor_of(node):
		return ""
	if node is ActorBase:
		if node.actor_id.is_empty():
			node.actor_id = String(document_root.get_path_to(node)).replace("/", "_")
		var current := node.get_parent()
		while current and current != document_root:
			if "instance_id" in current:
				return "%s/%s" % [current.get("instance_id"), node.actor_id]
			current = current.get_parent()
		return node.actor_id
	# Non-actor connections retain document-relative paths, never SceneTree paths.
	return String(document_root.get_path_to(node))


func find_actor(identity: String) -> Node:
	if not is_instance_valid(document_root):
		return null
	return _find_binding(document_root, identity)


func _find_binding(node: Node, identity: String) -> Node:
	for child: Node in node.get_children():
		if child.get_meta("editor_runtime_only", false):
			continue
		if get_binding_id(child) == identity:
			return child
		var found := _find_binding(child, identity)
		if found:
			return found
	return null


func _ids_from_nodes(nodes: Array) -> Array[String]:
	var identities: Array[String] = []
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		var identity := get_binding_id(node)
		if not identity.is_empty():
			identities.append(identity)
	return identities


func _nodes_from_ids(identities: Array) -> Array[Node]:
	var nodes: Array[Node] = []
	for identity: Variant in identities:
		var node := find_actor(str(identity))
		if node:
			nodes.append(node)
	return nodes


func get_all_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]
		for source: Node in channel.sources:
			for target: Node in channel.targets:
				if (
					is_instance_valid(source)
					and is_instance_valid(target)
					and document_root.is_ancestor_of(source)
					and document_root.is_ancestor_of(target)
				):
					result.append(
						{
							"source": source,
							"target": target,
							"channel": channel_name,
							"color": channel.color
						}
					)
	return result


func validate_data(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var identities: Dictionary = {}
	_collect_actor_identities(document_root, identities, errors)
	for channel_name: Variant in data:
		if (
			not channel_name is String
			or String(channel_name).is_empty()
			or not data[channel_name] is Dictionary
		):
			errors.append("Invalid channel record.")
			continue
		var saved: Dictionary = data[channel_name]
		if not saved.get("enabled", true) is bool or not saved.get("inverted", false) is bool:
			errors.append("Channel '%s' has invalid boolean settings." % channel_name)
		var delay: Variant = saved.get("delay", 0.0)
		if not (delay is int or delay is float) or not is_finite(float(delay)) or float(delay) < 0:
			errors.append("Channel '%s' has invalid delay." % channel_name)
		if (
			not saved.get("color", "ffffff") is String
			or not Color.html_is_valid(saved.get("color", "ffffff"))
		):
			errors.append("Channel '%s' has invalid color." % channel_name)
		for role: String in ["sources", "targets"]:
			if not saved.get(role, []) is Array:
				errors.append("Channel '%s' has invalid %s." % [channel_name, role])
				continue
			for identity: Variant in saved.get(role, []):
				if not identity is String or find_actor(identity) == null:
					errors.append(
						(
							"Channel '%s' has an unresolved %s binding: %s."
							% [channel_name, role, identity]
						)
					)
	return errors


func _collect_actor_identities(node: Node, identities: Dictionary, errors: Array[String]) -> void:
	for child: Node in node.get_children():
		if child.get_meta("editor_runtime_only", false):
			continue
		if child is ActorBase:
			var identity := get_binding_id(child)
			if identities.has(identity):
				errors.append("Duplicate actor identity: " + identity)
			identities[identity] = child
		_collect_actor_identities(child, identities, errors)
