extends SceneTree
## Executes real controller actions, captures evidence, and replays every case.

var errors: Array[String] = []
var cases: Array = []
var games: Array = []
var scene: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func make_game(scenario: int, disabled: bool = false) -> Node:
	var game := scene.instantiate()
	game.save_path = "user://diagnostic_test_progress.json"
	game.fixed_seed = 20261101
	game.recording_enabled = false
	game.recorder.output_dir = "user://playtest_verification"
	root.add_child(game)
	games.append(game)
	game.recording_enabled = true
	game.get_node("HUD/TestPanel/DisableSkills").set_pressed_no_signal(disabled)
	game.select_playtest(scenario + 1)
	return game

func match_pair(game: Node, a: int, b: int) -> void:
	check(BoardRules.can_match(game.tiles, a, b, game.board.tile_size), "Scripted pair must be legal: %d,%d" % [a, b])
	game._on_tile_pressed(a)
	game._on_tile_pressed(b)

func capture(game: Node, title: String) -> void:
	var record: Dictionary = game.recorder.report.duplicate(true)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.recorder.path))
	check(saved is Dictionary and saved.events.size() == record.events.size(), "Journal persisted after actions")
	# Replay the actual exported JSON, not just an in-memory copy.
	if saved is Dictionary:
		record = saved
	cases.append({"name": title, "record": record, "final": game._diagnostic()})

func _run() -> void:
	scene = load("res://scenes/main.tscn") as PackedScene
	check(not FileAccess.file_exists("user://diagnostic_test_progress.json"), "Diagnostic progress path isolated")
	for element in range(5):
		var game := make_game(0)
		match_pair(game, element * 2, element * 2 + 1)
		var effect: Dictionary = game.effect_trace.back()
		var expected := 2 if element == 3 else (0 if element == 4 else 1)
		check(effect.targets.size() == expected, "Basic exact target count: %d" % element)
		if element == 2:
			check(game.tiles[effect.targets[0]].liberated, "Water liberates instead of removing")
		if element == 4:
			check(game.protection == 1, "Earth adds one protection")
		capture(game, "basic_" + PetCatalog.element_for(PetCatalog.BASE_IDS[element]))
	var combo := make_game(1)
	for i in range(5):
		match_pair(combo, i * 2, i * 2 + 1)
		check(combo.combo_count == i + 1, "Manual earth chain reaches every tier")
	check(combo.protection == 11, "Five earth pairs grant 1+2+2+3+3")
	match_pair(combo, 10, 11)
	check(combo.has_won and combo.combo_count == 1, "Fire resets Combo and finishes fixture")
	capture(combo, "combo_continuous")
	var interrupted := make_game(1)
	match_pair(interrupted, 0, 1)
	match_pair(interrupted, 10, 11)
	for i in range(1, 5):
		match_pair(interrupted, i * 2, i * 2 + 1)
	check(interrupted.protection == 9 and interrupted.has_won, "Interrupted route grants nine protection")
	capture(interrupted, "combo_interrupted")
	var bad := make_game(2)
	match_pair(bad, 0, 1)
	check(BoardRules.remaining_count(bad.tiles) == 3, "Fire leaves three tiles")
	check(bad._diagnostic().reason == "recoverable_blocked_pairs", "Fire route requires recovery")
	bad.shuffle_board()
	var pair := BoardRules.first_available_pair(bad.tiles, bad.board.tile_size)
	check(pair.size() == 2, "Shuffle creates legal pair")
	if pair.size() == 2:
		match_pair(bad, pair[0], pair[1])
	check(bad.has_failed and bad._diagnostic().reason == "no_matching_identities", "One orphan loses even with shuffle charge")
	check(bad.shuffle_remaining == 1 and BoardRules.remaining_count(bad.tiles) == 1, "Failure is identities, not exhausted resources")
	capture(bad, "orphan_fire_shuffle_loss")
	for i in range(3):
		bad.undo_last_match()
	check(BoardRules.remaining_count(bad.tiles) == 6, "Three undos restore original orphan fixture")
	match_pair(bad, 4, 5)
	match_pair(bad, 2, 3)
	match_pair(bad, 0, 1)
	check(bad.has_won, "Undo and alternate route win")
	capture(bad, "orphan_undo_recovery")
	var good := make_game(2)
	match_pair(good, 4, 5)
	match_pair(good, 2, 3)
	match_pair(good, 0, 1)
	check(good.has_won and good.shuffle_remaining == 2, "Wind-first route wins without shuffle")
	capture(good, "orphan_wind_first_win")
	var water := make_game(3)
	match_pair(water, 0, 1)
	check(water.tiles[2].liberated, "Water opens covered fire partner")
	match_pair(water, 2, 3)
	match_pair(water, 4, 5)
	check(water.has_won, "Water-enabled route clears")
	capture(water, "water_enabled_win")
	var water_off := make_game(3, true)
	match_pair(water_off, 0, 1)
	check(water_off.has_failed and BoardRules.remaining_count(water_off.tiles) == 4, "Without water, blocked partners lose")
	capture(water_off, "water_disabled_loss")
	var earth := make_game(4)
	match_pair(earth, 0, 1)
	check(earth.protection == 1 and not earth.has_failed and earth.shuffle_remaining == 0, "Earth funds otherwise unavailable recovery")
	earth.shuffle_board()
	check(earth.protection == 0 and earth.shuffle_remaining == 0, "Earth protection pays shuffle")
	for i in range(2):
		var recovery_pair := BoardRules.first_available_pair(earth.tiles, earth.board.tile_size)
		check(recovery_pair.size() == 2, "Recovery leaves legal pair")
		if recovery_pair.size() == 2:
			match_pair(earth, recovery_pair[0], recovery_pair[1])
	check(earth.has_won, "Earth-enabled recovery clears")
	capture(earth, "earth_enabled_win")
	var earth_off := make_game(4, true)
	match_pair(earth_off, 0, 1)
	check(earth_off.has_failed and earth_off.protection == 0, "Without earth, no recovery resource")
	capture(earth_off, "earth_disabled_loss")
	# Re-run journal actions; timestamps and output paths do not affect board state.
	for evidence in cases:
		var replay := make_game(int(evidence.record.metadata.scenario), bool(evidence.record.metadata.get("skills_disabled", false)))
		# JSON parses numbers as floats; compare both states in wire representation.
		check(JSON.parse_string(JSON.stringify(replay._diagnostic())) == evidence.record.initial, "Replayed initial state: " + evidence.name)
		for event in evidence.record.events:
			match event.action:
				"manual_match": match_pair(replay, int(event.details.pair[0]), int(event.details.pair[1]))
				"shuffle": replay.shuffle_board()
				"undo": replay.undo_last_match()
			check(JSON.parse_string(JSON.stringify(replay._diagnostic())) == event.after, "Replayed action state: " + evidence.name)
	var campaign := make_game(-1)
	campaign.recording_enabled = false
	var first: Dictionary = campaign._snapshot()
	campaign.new_game()
	check(campaign._snapshot() == first, "Same seed repeats campaign deck")
	campaign.shuffle_board()
	var shuffled: Dictionary = campaign._snapshot()
	campaign.undo_last_match()
	campaign.shuffle_board()
	check(campaign._snapshot() == shuffled, "Shuffle repeats after undo")
	check(not FileAccess.file_exists("user://diagnostic_test_progress.json"), "Playtests never save campaign progress")
	var controls := make_game(0)
	controls.show_hint()
	controls.toggle_pause()
	controls.toggle_pause()
	check(controls.recorder.report.events.size() == 3, "Manual hint and pause operations journaled")
	var output := FileAccess.open("res://docs/PLAYTEST_RESULTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"seed": 20261101, "case_count": cases.size(), "errors": errors, "cases": cases}, "\t"))
	output.close()
	for game in games:
		DirAccess.remove_absolute(game.recorder.path)
	if errors.is_empty():
		print("Playtests passed: %d scripted cases, journal persistence/replay, deterministic campaign/shuffle, progress isolation" % cases.size())
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
