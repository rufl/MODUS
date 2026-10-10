class_name Backpack
extends RigidBody3D

signal collected(by_peer_id: int)
signal interaction_denied(by_peer_id: int, reason: String)

@export var owner_uuid: String = ""
@export var owner_peer_id: int = 0
@export var inventory_data: Dictionary = {}
@export var xp_amount: int = 0
@export var owner_name: String = "Unknown"

var interactable_type: String = "Backpack"
var interaction_text: String = "Retrieve Backpack"

@onready var interaction_area: Area3D = $InteractionArea
@onready var label_3d: Label3D = $Label3D


func _ready() -> void:
	# Initial setup
	if owner_name != "":
		update_label()

	# Setup interaction
	collision_layer = CollisionLayers.LAYER_INTERACTABLES

	# Only server needs to process physics logic for pickup?
	# Actually, client initiates interaction.


func setup(uuid: String, peer_id: int, name_str: String, inv: Dictionary, xp: int) -> void:
	owner_uuid = uuid
	owner_peer_id = peer_id
	owner_name = name_str
	inventory_data = inv
	xp_amount = xp

	update_label()

	# Sync vital data to clients if spawned on server
	if multiplayer.is_server():
		_sync_backpack_data.rpc(uuid, peer_id, name_str, xp)


func update_label() -> void:
	if label_3d:
		label_3d.text = "%s's Backpack\n(XP: %d)" % [owner_name, xp_amount]
		# Color code?


func interact(interactor: Node) -> void:
	# Check if interactor is the owner
	# We need to check UUID match.
	# Assuming 'interactor' is the Player node.

	var is_owner: bool = false
	var interactor_uuid: String = ""

	if "uuid" in interactor:
		interactor_uuid = interactor.uuid
	else:
		var gs := _get_gameplay_service()
		if gs and gs.player:
			# Fallback to looking up UUID by peer ID if available
			var pid: int = interactor.get_multiplayer_authority()
			interactor_uuid = gs.player.get_player_uuid(pid)

	var interactor_peer_id: int = interactor.get_multiplayer_authority()
	if (
		(owner_peer_id > 0 and interactor_peer_id == owner_peer_id)
		or (not owner_uuid.is_empty() and interactor_uuid == owner_uuid)
	):
		is_owner = true

	if not is_owner:
		interaction_denied.emit(interactor_peer_id, "Not your backpack")
		return

	# Request retrieval
	if multiplayer.is_server():
		_retrieve(interactor)
	else:
		_request_retrieve.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_retrieve() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	# Find sender player node
	var player: Node = _get_player_by_id(sender_id)
	if (
		not player
		or not player is Node3D
		or player.global_position.distance_to(global_position) > 3.5
	):
		return

	# Double check ownership on server
	var gs := _get_gameplay_service()
	var p_uuid: String = gs.player.get_player_uuid(sender_id) if gs and gs.player else ""
	if sender_id == owner_peer_id or (not owner_uuid.is_empty() and p_uuid == owner_uuid):
		_retrieve(player)


func _retrieve(player: Node) -> void:
	var peer_id: int = player.get_multiplayer_authority()
	var gs := _get_gameplay_service()
	var player_inv: Inventory = null
	if gs and gs.inventory:
		player_inv = gs.inventory.get_inventory(peer_id)
	if not player_inv or not _restore_inventory(player_inv):
		push_warning("[Backpack] Cannot restore inventory for peer %d" % peer_id)
		return

	if "progression" in player and player.progression:
		player.progression.add_xp(xp_amount)

	if gs and gs.inventory and gs.inventory.has_method("sync_inventory"):
		gs.inventory.sync_inventory(peer_id)

	collected.emit(peer_id)
	queue_free()


func _sync_backpack_data(uuid: String, peer_id: int, name_str: String, xp: int) -> void:
	owner_uuid = uuid
	owner_peer_id = peer_id
	owner_name = name_str
	xp_amount = xp
	update_label()


func _restore_inventory(target: Inventory) -> bool:
	if not target:
		return false

	var saved_inventory := Inventory.new()
	saved_inventory.from_dict(inventory_data)

	# Merge into a copy first so a full inventory cannot partially consume the
	# backpack. The target changes only after every item fits.
	var merged_inventory := Inventory.new()
	merged_inventory.from_dict(target.to_dict())
	for slot_item: InventoryItem in saved_inventory.slots:
		if (
			slot_item
			and not merged_inventory.add_item(
				slot_item.duplicate_with_stack(slot_item.current_stack)
			)
		):
			return false

	for slot_name: String in Inventory.EQUIPMENT_SLOTS:
		var equipped_item: InventoryItem = saved_inventory.equipment.get(slot_name)
		if not equipped_item:
			continue
		if merged_inventory.equipment.get(slot_name):
			if not merged_inventory.add_item(
				equipped_item.duplicate_with_stack(equipped_item.current_stack)
			):
				return false
		else:
			merged_inventory.equip_item(
				equipped_item.duplicate_with_stack(equipped_item.current_stack), slot_name
			)

	target.from_dict(merged_inventory.to_dict())
	return true


func _get_player_by_id(pid: int) -> Node:
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_multiplayer_authority() == pid:
			return node
	return null


func _get_gameplay_service() -> GameplaySvc:
	var gm: Node = get_node_or_null("/root/GameManager")
	return gm.get_core_system("gameplay") as GameplaySvc if gm else null
