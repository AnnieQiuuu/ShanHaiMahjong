extends SceneTree

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.recording_enabled = false
	game.fixed_seed = 20261101
	game.save_path = "user://release_features_progress.json"
	root.add_child(game)
	check(not game.get_node("HUD/TestPanel").visible, "Testing tools start collapsed")
	game.toggle_test_panel()
	check(game.get_node("HUD/TestPanel").visible, "Testing tools expand")
	game.toggle_test_panel()
	for index in range(8):
		check(not game.get_node("HUD/LevelSelect").is_item_disabled(index), "All eight regions selectable")
		game.select_level(index)
		check(game.level_index == index, "Direct region selection")
		var counts: Dictionary = {}
		var species: Dictionary = {}
		for tile in game.tiles:
			var element := PetCatalog.element_for(tile.pet_id)
			counts[element] = int(counts.get(element, 0)) + 1
			species[tile.pet_id] = true
		var config: Dictionary = LevelCatalog.LEVELS[index]
		for element in config.element_pairs:
			check(counts[element] == int(config.element_pairs[element]) * 2, "Actual deal respects element quota")
		check(species.size() == int(config.species), "Quota preserves species count")
		if index >= 3:
			check(counts.lightning >= 10 and counts.earth >= 10, "Later deals include at least five manual pairs of lightning/earth")
	# Two top blockers have identical opening value; prefer the one with 3 copies
	# over the one whose removal destroys its final pair.
	var fixture: Array[MahjongTileState] = []
	for i in range(7):
		var tile := MahjongTileState.new(i, 0, i * 2, 0, Vector2(i * 220, 0))
		tile.pet_id = "030"
		fixture.append(tile)
	fixture[2].layer = 1
	fixture[2].position = fixture[0].position
	fixture[2].pet_id = "001"
	fixture[3].pet_id = "001"
	fixture[4].layer = 1
	fixture[4].position = fixture[1].position
	for i in [4, 5, 6]:
		fixture[i].pet_id = "002"
	check(ElementRules.blocker_target(fixture, game.board.tile_size, ["001", "002"], false) == 4, "Fire avoids breaking last pair when safer blocker exists")
	check(ElementRules.blocker_target(fixture, game.board.tile_size, ["001", "002"], true) == 4, "Wind avoids breaking last pair when safer blocker exists")
	game.select_playtest(5)
	game._on_tile_pressed(0)
	game._on_tile_pressed(1)
	check(game.get_node("HUD/Deadlock").visible and not game.has_failed, "Recoverable deadlock modal")
	check("护佑" in game.get_node("HUD/Deadlock/Panel/Actions/Shuffle").text, "Recovery button explains protection cost")
	game.get_node("HUD/Deadlock/Panel/Actions/Shuffle").pressed.emit()
	check(not game.get_node("HUD/Deadlock").visible and game.protection == 0, "Modal shuffle recovers board")
	game.get_node("HUD/TestPanel/DisableSkills").set_pressed_no_signal(true)
	game.new_game()
	game._on_tile_pressed(0)
	game._on_tile_pressed(1)
	check(game.has_failed and game.get_node("HUD/Deadlock/Panel/Actions/Shuffle").disabled, "Resource-exhausted modal disables shuffle")
	check("用尽" in game.get_node("HUD/Deadlock/Panel/Details").text, "Resource-exhausted explanation")
	game.get_node("HUD/Deadlock/Panel/Review").pressed.emit()
	game._refresh()
	check(not game.get_node("HUD/Deadlock").visible, "Review dismissal stays closed")
	game.get_node("HUD/TestPanel/DisableSkills").set_pressed_no_signal(false)
	game.select_playtest(3)
	game._on_tile_pressed(0)
	game._on_tile_pressed(1)
	game.shuffle_board()
	var pair := BoardRules.first_available_pair(game.tiles, game.board.tile_size)
	game._on_tile_pressed(pair[0])
	game._on_tile_pressed(pair[1])
	check(game.has_failed and "没有同种" in game.get_node("HUD/Deadlock/Panel/Details").text, "Orphan explanation differs from resource failure")
	DirAccess.remove_absolute(game.save_path)
	if errors.is_empty():
		print("Release features passed: eight unlocked regions, exact element quotas, safer single targets, collapsed tools, recoverable/resource/orphan deadlock dialogs")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
