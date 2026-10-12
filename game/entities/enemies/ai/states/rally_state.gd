class_name EnemyRallyState
extends EnemyState

@export var rally_radius: float = 10.0
@export var damage_multiplier: float = 1.25
@export var refresh_interval: float = 0.25

var _refresh_timer: float = 0.0
var _rallied_allies: Dictionary = {}


func enter() -> void:
	_refresh_timer = 0.0
	if controller.movement:
		controller.movement.stop()
	_refresh_rally()


func exit() -> void:
	_clear_rally()


func physics_update(delta: float) -> void:
	if not controller or not controller.parent_body:
		return

	var target: Node3D = controller.target
	if target and is_instance_valid(target) and controller.combat:
		if controller.combat.can_attack(target):
			var attack_state := controller.get_node_or_null("AttackState") as EnemyState
			if attack_state:
				controller.change_state(attack_state)
				return

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = refresh_interval
		_refresh_rally()


func _refresh_rally() -> void:
	if not controller or not controller.parent_body or not is_inside_tree():
		return

	var body := controller.parent_body
	var radius_sq: float = rally_radius * rally_radius
	var current_allies: Dictionary = {}
	for ally: Node in get_tree().get_nodes_in_group("enemies"):
		if ally == body or not ally is Node3D or not is_instance_valid(ally):
			continue
		if body.global_position.distance_squared_to(ally.global_position) > radius_sq:
			continue

		var combat := ally.get_node_or_null("CombatComponent") as CombatComponent
		if not combat:
			continue
		var key: int = combat.get_instance_id()
		current_allies[key] = true
		if not _rallied_allies.has(key):
			_rallied_allies[key] = {"combat": combat, "base_damage": combat.attack_damage}
			combat.attack_damage *= damage_multiplier

	for key: int in _rallied_allies.keys():
		if not current_allies.has(key):
			_restore_ally(key)


func _clear_rally() -> void:
	for key: int in _rallied_allies.keys().duplicate():
		_restore_ally(key)


func _restore_ally(key: int) -> void:
	var entry: Dictionary = _rallied_allies.get(key, {})
	var combat: CombatComponent = entry.get("combat") as CombatComponent
	if combat and is_instance_valid(combat):
		combat.attack_damage = float(entry.get("base_damage", combat.attack_damage))
	_rallied_allies.erase(key)
