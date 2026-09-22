extends ModusGutTestBase

const ORIGIN := "res://tests/fixtures/hub_travel_origin.tscn"
const DESTINATION := "res://tests/fixtures/hub_travel_destination.tscn"
var _session: LevelPlaySession
var _peer: ENetMultiplayerPeer
var _previous_peer: MultiplayerPeer


func before_each() -> void:
	await modus_setup()
	_previous_peer = multiplayer.multiplayer_peer
	_peer = ENetMultiplayerPeer.new()
	assert_eq(_peer.create_server(0), OK)
	multiplayer.multiplayer_peer = _peer
	_session = LevelPlaySession.new()
	_session.name = "TravelSession"
	add_child(_session)
	_session.register_destination("travel_origin", ORIGIN)
	_session.register_destination("travel_destination", DESTINATION)
	assert_true(await _session.travel_to("travel_origin", "arrival"), _session.error_message)
	_session.set_travel_frozen(true)


func after_each() -> void:
	_session.free()
	multiplayer.multiplayer_peer = _previous_peer
	_peer.close()
	modus_teardown()


func test_revisit_preserves_world_rewards_and_party_without_rehosting() -> void:
	var participant := _session.player
	var power: SwitchActor = _session.document.find_actor("power")
	power.trigger(participant)
	var key: KeyPickupActor = _session.document.find_actor("key")
	assert_true(key.interact(participant))
	participant.health_component.set_health(50.0, 7.0)
	var supplies: PickupSpawnerActor = _session.document.find_actor("supplies")
	participant.global_position = supplies._current_pickup.global_position
	assert_not_null(supplies._current_pickup)
	assert_true(supplies._current_pickup.collect_for_player(participant, 1))
	var health := participant.health_component.current_health
	var item := InventoryItem.new()
	item.id = "hub_token"
	item.display_name = "Hub token"
	assert_true(participant.inventory.add_item(item))
	var inventory := participant.inventory.to_dict()
	var encounter: EnemySpawnerActor = _session.document.find_actor("encounter")
	encounter.trigger(participant)
	assert_eq(encounter._enemies.size(), 1)
	var enemy: Enemy = encounter._enemies[0]
	enemy.take_damage(10000.0, 1, Vector3.ZERO, 0.0, "bullet", participant)
	encounter._process(0.0)
	MissionMgr.get_instance()._process(0.0)

	assert_true(await _session.travel_to("travel_destination", "arrival"), _session.error_message)
	_session.set_travel_frozen(true)
	assert_same(multiplayer.multiplayer_peer, _peer, "Travel preserves the bound transport")
	assert_eq(_peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	assert_same(
		_session.player, participant, "Party nodes and inventory survive destination replacement"
	)
	assert_true(participant.global_position.is_equal_approx(Vector3(4, 1.2, 4)))
	assert_eq(participant.inventory.to_dict(), inventory)
	assert_true(await _session.travel_to("travel_origin", "arrival"), _session.error_message)
	_session.set_travel_frozen(true)
	assert_eq(_session.document.find_actor("power").activation_count, 1)
	assert_eq(MissionMgr.get_instance().completed_mission_id, "travel_origin")
	assert_true(participant.has_item("hub_key"))
	assert_eq(participant.health_component.current_health, health, "Revisit grants no supplies")
	assert_eq(
		_session.document.find_actor("supplies").capture_runtime_state().pickup_phase, "collected"
	)
	assert_true(_session.document.find_actor("encounter").capture_runtime_state().encounter_cleared)
	assert_eq(_session.document.find_actor("encounter")._enemies.size(), 0)
	assert_eq(participant.inventory.to_dict(), inventory)


func test_rejected_destination_and_corrupt_campaign_leave_current_world_usable() -> void:
	var document := _session.document
	var participant := _session.player
	var snapshot := _session.capture_campaign_state()
	assert_false(await _session.travel_to("travel_destination", "missing-spawn"))
	assert_same(_session.document, document)
	assert_same(_session.player, participant)
	assert_same(multiplayer.multiplayer_peer, _peer)
	var corrupted := snapshot.duplicate(true)
	corrupted.destinations.travel_origin.runtime.actors.power.activation_count = -1
	assert_false(await _session.restore_campaign_state(corrupted))
	assert_same(_session.document, document)
	assert_eq(_session.capture_campaign_state(), snapshot)
	assert_true(
		_session.document.find_actor("power").interact(participant),
		"Failed travel leaves interactions usable"
	)


func test_encrypted_checkpoint_restores_all_visited_destinations() -> void:
	var state_manager: Node = GameManager.get_core_system("state_manager")
	var save_service: Node = GameManager.get_core_system("save")
	_session.document.find_actor("power").trigger(_session.player)
	MissionMgr.get_instance()._process(0.0)
	assert_true(await _session.travel_to("travel_destination"), _session.error_message)
	_session.set_travel_frozen(true)
	assert_true(state_manager.save_game("hub_travel_regression"))
	_session.free()
	_session = LevelPlaySession.new()
	_session.name = "TravelSession"
	add_child(_session)
	_session.register_destination("travel_origin", ORIGIN)
	_session.register_destination("travel_destination", DESTINATION)
	assert_true(await _session.travel_to("travel_origin"), _session.error_message)
	assert_true(await state_manager.load_game("hub_travel_regression"))
	_session.set_travel_frozen(true)
	assert_eq(_session.current_destination_id, "travel_destination")
	assert_true(await _session.travel_to("travel_origin"), _session.error_message)
	_session.set_travel_frozen(true)
	assert_eq(_session.document.find_actor("power").activation_count, 1)
	assert_same(multiplayer.multiplayer_peer, _peer)
	save_service.delete_save("hub_travel_regression")
