extends Node2D
## Coordinates manual moves and atomic element turns. Views only present state.

@onready var board: MahjongBoardView = $MahjongBoard
@onready var counter_label: Label = $HUD/Counter
@onready var feedback_label: Label = $HUD/Feedback

var tiles: Array[MahjongTileState] = []
var selected_id := -1
var move_history: Array[Dictionary] = []
var hinted_ids: Array[int] = []
var hint_expires_at := 0
var has_won := false
var has_failed := false
var is_paused := false
var level_index := 0
var unlocked_level := 0
var undo_remaining := 3
var shuffle_remaining := 2
var protection := 0
var combo_element := ""
var combo_count := 0
var discovered: Array = []
var first_regions: Dictionary = {}
var notice := ""
var save_error := false
var collection_selection := 0
const SAVE_PATH := "user://mvp_progress.json"
var save_path := SAVE_PATH
var fixed_seed := -1
var deal_seed := 0
var shuffle_sequence := 0
var playtest_index := -1
var recording_enabled := true
var recorder := PlaytestRecorder.new()
var effect_trace: Array = []
var victory_dismissed := false
@export var all_regions_unlocked := true
@export var animate_effects := true
var is_resolving := false
var turn_token := 0
var deadlock_dismissed := false

func _ready() -> void:
	_load_progress()
	board.tile_pressed.connect(_on_tile_pressed)
	board.tile_inspected.connect(_on_tile_inspected)
	$HUD/Victory/Panel/Actions/Next.pressed.connect(next_level)
	$HUD/Victory/Panel/Actions/Restart.pressed.connect(new_game)
	$HUD/Victory/Panel/Actions/Review.pressed.connect(func(): victory_dismissed = true; $HUD/Victory.hide())
	$HUD/Deadlock/Panel/Actions/Shuffle.pressed.connect(shuffle_board)
	$HUD/Deadlock/Panel/Actions/Undo.pressed.connect(undo_last_match)
	$HUD/Deadlock/Panel/Actions/Restart.pressed.connect(new_game)
	$HUD/Deadlock/Panel/Review.pressed.connect(func(): deadlock_dismissed = true; $HUD/Deadlock.hide())
	$HUD/TestToggle.pressed.connect(toggle_test_panel)
	$HUD/TestPanel/DisableSkills.toggled.connect(func(_value): new_game())
	for i in range(LevelCatalog.LEVELS.size()):
		$HUD/LevelSelect.add_item("第%d关 · %s" % [i + 1, LevelCatalog.LEVELS[i].name])
	$HUD/LevelSelect.item_selected.connect(select_level)
	$HUD/Restart.pressed.connect(new_game)
	$HUD/Undo.pressed.connect(undo_last_match)
	$HUD/Hint.pressed.connect(show_hint)
	$HUD/Shuffle.pressed.connect(shuffle_board)
	$HUD/Next.pressed.connect(next_level)
	$HUD/Pause.pressed.connect(toggle_pause)
	$HUD/Collection.pressed.connect(func(): $HUD/CollectionPanel.visible = not $HUD/CollectionPanel.visible)
	$HUD/CollectionPanel/Grid.item_selected.connect(_on_collection_selected)
	$HUD/TestPanel/PlaytestSelect.add_item("正式八地区")
	for title in PlaytestCatalog.NAMES:
		$HUD/TestPanel/PlaytestSelect.add_item("测试 · " + title)
	$HUD/TestPanel/PlaytestSelect.item_selected.connect(select_playtest)
	$HUD/TestPanel/ExportLog.pressed.connect(export_log)
	new_game()

func select_playtest(index: int) -> void:
	playtest_index = index - 1
	$HUD/TestPanel/PlaytestSelect.select(index)
	_load_progress()
	new_game()

func toggle_test_panel() -> void:
	$HUD/TestPanel.visible = not $HUD/TestPanel.visible
	$HUD/TestToggle.text = "收起测试工具" if $HUD/TestPanel.visible else "测试工具"

func export_log() -> void:
	if is_resolving:
		return
	recorder.flush()
	notice = "记录写入失败" if recorder.write_error else "记录已保存，路径可在弹窗复制"
	if not recorder.write_error:
		$HUD/LogPath/Path.text = ProjectSettings.globalize_path(recorder.path)
		$HUD/LogPath.popup_centered(Vector2i(760, 200))
	_refresh()

func select_level(index: int) -> void:
	if index < 0 or (index > unlocked_level and not all_regions_unlocked) or index >= LevelCatalog.LEVELS.size():
		$HUD/LevelSelect.select(level_index)
		return
	level_index = index
	playtest_index = -1
	$HUD/TestPanel/PlaytestSelect.select(0)
	_load_progress()
	new_game()

func next_level() -> void:
	if playtest_index < 0 and has_won and level_index + 1 < LevelCatalog.LEVELS.size():
		select_level(level_index + 1)

func new_game() -> void:
	turn_token += 1
	is_resolving = false
	board.input_enabled = true
	board.clear_feedback()
	deadlock_dismissed = false
	$HUD/Deadlock.hide()
	$HUD/SkillStage.text = "配对后，五行自动触发"
	selected_id = -1
	move_history.clear()
	hinted_ids.clear()
	has_won = false
	has_failed = false
	is_paused = false
	victory_dismissed = false
	$HUD/Victory.hide()
	combo_element = ""
	combo_count = 0
	protection = 0
	shuffle_sequence = 0
	effect_trace.clear()
	notice = ""
	var seed_text: String = $HUD/TestPanel/SeedInput.text.strip_edges()
	deal_seed = fixed_seed if fixed_seed >= 0 else (int(seed_text) if seed_text.is_valid_int() else int(Time.get_ticks_usec() % 2147483647))
	var config: Dictionary = LevelCatalog.LEVELS[level_index]
	undo_remaining = int(config.undo)
	shuffle_remaining = int(config.shuffle)
	tiles = BoardGenerator.create_level_layout(config, board.column_row_step, board.layer_offset)
	var pool := LevelCatalog.pet_ids_for(config, deal_seed)
	if playtest_index >= 0:
		tiles = PlaytestCatalog.create(playtest_index, board.column_row_step, board.layer_offset)
		discovered = PetCatalog.BASE_IDS.duplicate()
		first_regions = {}
		undo_remaining = 3
		shuffle_remaining = 2
		if playtest_index >= 3:
			shuffle_remaining = 0
	elif not BoardGenerator.assign_solvable_pairs(tiles, board.tile_size, pool, deal_seed, [], LevelCatalog.pair_ids_for(config, pool, deal_seed)):
		has_failed = true
		notice = "生成失败，请重开"
		push_error(notice)
	board.display_board(tiles)
	_refresh()
	recorder.enabled = recording_enabled
	var geometry: Array = []
	for tile in tiles:
		geometry.append({"id": tile.id, "layer": tile.layer, "row": tile.row, "column": tile.column, "position": [tile.position.x, tile.position.y]})
	var rules_source := ""
	for file in ["res://scripts/rules/board_rules.gd", "res://scripts/rules/element_rules.gd", "res://scripts/generation/board_generator.gd", "res://scripts/game/game_controller.gd", "res://scripts/data/playtest_catalog.gd"]:
		rules_source += FileAccess.get_file_as_string(file)
	recorder.begin({"seed": deal_seed, "rules_hash": rules_source.sha256_text(), "scenario": playtest_index, "skills_disabled": playtest_index >= 0 and $HUD/TestPanel/DisableSkills.button_pressed, "name": config.name if playtest_index < 0 else PlaytestCatalog.NAMES[playtest_index], "discovered": discovered.duplicate(), "geometry": geometry, "tile_size": [board.tile_size.x, board.tile_size.y], "config": config.duplicate(true)}, _diagnostic())

func _on_tile_pressed(index: int) -> void:
	if has_won or has_failed or is_paused or is_resolving:
		return
	if index < 0 or index >= tiles.size() or not BoardRules.is_free(tiles, index, board.tile_size):
		return
	if selected_id == index:
		selected_id = -1
	elif selected_id < 0:
		selected_id = index
	elif BoardRules.can_match(tiles, selected_id, index, board.tile_size):
		var before := _diagnostic()
		var manual_pair := [selected_id, index]
		move_history.append(_snapshot())
		var pet: String = tiles[index].pet_id
		tiles[selected_id].removed = true
		tiles[index].removed = true
		var element := PetCatalog.element_for(pet)
		combo_count = combo_count + 1 if element == combo_element else 1
		combo_element = element
		notice = ""
		if pet not in discovered:
			discovered.append(pet)
			first_regions[pet] = LevelCatalog.LEVELS[level_index].region
			notice = "NEW %s · %s · %d/%d" % [PetCatalog.name_for(pet), PetCatalog.ELEMENT_NAMES[element], discovered.size(), PetCatalog.IDS.size()]
			_save_progress()
		selected_id = -1
		hinted_ids.clear()
		deadlock_dismissed = false
		is_resolving = true
		board.input_enabled = false
		# Keep target tiles visible until their preview has finished.
		board.refresh(-1, [])
		counter_label.text = "剩余 %d / %d" % [BoardRules.remaining_count(tiles), tiles.size()]
		$HUD/Combo.text = "%s ×%d" % [PetCatalog.ELEMENT_NAMES[element], combo_count]
		var triggered_strength := mini(combo_count, 5)
		_resolve_element(element)
		var visual_targets: Array = []
		var newly_free: Array = []
		for effect in effect_trace:
			visual_targets.append_array(effect.get("targets", []))
			newly_free.append_array(effect.get("newly_free", []))
		var token := turn_token
		if animate_effects and DisplayServer.get_name() != "headless" and not (playtest_index >= 0 and $HUD/TestPanel/DisableSkills.button_pressed):
			$HUD/SkillStage.text = "%s ×%d · 目标预告" % [PetCatalog.ELEMENT_NAMES[element], triggered_strength]
			for button in [$HUD/Undo, $HUD/Hint, $HUD/Shuffle, $HUD/Pause]:
				button.disabled = true
			board.show_element_feedback(element, manual_pair, visual_targets)
			await get_tree().create_timer(board.effect_duration).timeout
			if token != turn_token:
				return
		is_resolving = false
		board.input_enabled = true
		_refresh()
		board.flash_released(newly_free)
		if playtest_index >= 0 and $HUD/TestPanel/DisableSkills.button_pressed:
			$HUD/SkillStage.text = "对照：元素效果关闭"
		elif element == "earth":
			$HUD/SkillStage.text = "土 · 护佑已增加"
		else:
			$HUD/SkillStage.text = "%s · 新解锁%d张" % [PetCatalog.ELEMENT_NAMES[element], newly_free.size()]
		recorder.record("manual_match", before, _diagnostic(), {"pair": manual_pair, "pet": pet, "element": element, "effects": effect_trace})
		return
	else:
		selected_id = index
	_refresh()

func _resolve_element(element: String) -> void:
	effect_trace.clear()
	if playtest_index >= 0 and $HUD/TestPanel/DisableSkills.button_pressed:
		notice = "对照测试：元素效果关闭"
		effect_trace.append({"kind": "disabled", "targets": [], "newly_free": []})
		return
	var effect_before := _diagnostic()
	var targets: Array = []
	var strength := mini(combo_count, 5)
	var amount := mini(strength, 4)
	if strength == 4 and element in ["wind", "water"]:
		amount = 3
	var affected := 0
	match element:
		"earth":
			var gains: Array[int] = [1, 2, 2, 3, 3]
			protection += gains[strength - 1]
			affected = gains[strength - 1]
			if strength == 3:
				show_hint(false)
			if strength >= 5 and BoardRules.first_available_pair(tiles, board.tile_size).is_empty() and BoardRules.remaining_count(tiles) > 0:
				var shuffle_seed := _next_shuffle_seed()
				if BoardGenerator.shuffle_remaining(tiles, board.tile_size, shuffle_seed):
					effect_trace.append({"kind": "earth_free_shuffle", "seed": shuffle_seed})
					combo_count = 0
					combo_element = ""
		"water":
			for i in range(amount):
				var target := ElementRules.water_target(tiles, board.tile_size)
				if target < 0:
					break
				tiles[target].liberated = true
				targets.append(target)
				affected += 1
		"fire", "wind", "lightning":
			if element == "lightning":
				amount = 3 if strength == 5 else (2 if strength >= 3 else 1)
			for i in range(amount):
				var pair: Array[int]
				if element == "lightning":
					pair = ElementRules.best_pair(tiles, board.tile_size, discovered)
				else:
					var target := ElementRules.blocker_target(tiles, board.tile_size, discovered, element == "wind")
					pair = []
					if target >= 0:
						pair.append(target)
				if pair.is_empty():
					break
				for id in pair:
					targets.append(id)
					tiles[id].removed = true
				affected += 1
			if element == "lightning" and strength == 2:
				show_hint(false)
			if element == "lightning" and strength == 4:
				var target := ElementRules.blocker_target(tiles, board.tile_size, discovered, false)
				if target >= 0:
					tiles[target].removed = true
					targets.append(target)
	var effect_after := _diagnostic()
	var newly_free: Array = []
	var target_pets: Array = []
	for id in effect_after.free_tiles:
		if id not in effect_before.free_tiles:
			newly_free.append(id)
	for id in targets:
		target_pets.append(effect_before.tiles[id][0])
	effect_trace.append({"kind": element, "strength": strength, "targets": targets, "target_pets": target_pets, "newly_free": newly_free, "available_before": effect_before.free_tiles.size(), "available_after": effect_after.free_tiles.size(), "pairs_before": effect_before.legal_pairs.size(), "pairs_after": effect_after.legal_pairs.size()})
	var descriptions := {"fire": "炸除%d张", "wind": "吹走%d张", "water": "解放%d张 · 蓝框可选", "lightning": "自动消除%d对", "earth": "护佑+%d"}
	var effect_text := "%s ×%d · %s" % [PetCatalog.ELEMENT_NAMES.get(element, ""), strength, "暂无合适目标" if affected == 0 else descriptions[element] % affected]
	notice = effect_text if notice.is_empty() else notice + "\n" + effect_text

func _snapshot() -> Dictionary:
	var states: Array = []
	for tile in tiles:
		states.append([tile.pet_id, tile.removed, tile.liberated])
	return {"tiles": states, "element": combo_element, "combo": combo_count, "protection": protection, "shuffle": shuffle_remaining, "shuffle_sequence": shuffle_sequence}

func _next_shuffle_seed() -> int:
	shuffle_sequence += 1
	return deal_seed + shuffle_sequence * 104729

func _diagnostic() -> Dictionary:
	var result := _snapshot()
	var free: Array = []
	var pairs: Array = []
	var counts: Dictionary = {}
	for i in range(tiles.size()):
		if not tiles[i].removed:
			counts[tiles[i].pet_id] = int(counts.get(tiles[i].pet_id, 0)) + 1
		if BoardRules.is_free(tiles, i, board.tile_size):
			free.append(i)
	for a in range(free.size()):
		for b in range(a + 1, free.size()):
			if tiles[free[a]].pet_id == tiles[free[b]].pet_id:
				pairs.append([free[a], free[b]])
	var has_duplicate := false
	var singles: Array = []
	for id in counts:
		has_duplicate = has_duplicate or counts[id] >= 2
		if counts[id] == 1:
			singles.append(id)
	var reason := "playable"
	if counts.is_empty():
		reason = "cleared"
	elif pairs.is_empty():
		if not has_duplicate:
			reason = "no_matching_identities"
		elif free.size() < 2:
			reason = "insufficient_free_positions"
		elif shuffle_remaining <= 0 and protection <= 0:
			reason = "shuffle_resources_exhausted"
		else:
			reason = "recoverable_blocked_pairs"
	result.merge({"free_tiles": free, "legal_pairs": pairs, "remaining": BoardRules.remaining_count(tiles), "counts": counts, "singletons": singles, "reason": reason, "undo_remaining": undo_remaining, "discovered": discovered.duplicate(), "paused": is_paused})
	return result

func undo_last_match() -> void:
	if is_paused or is_resolving or move_history.is_empty() or undo_remaining <= 0:
		return
	victory_dismissed = false
	deadlock_dismissed = false
	var before := _diagnostic()
	var snapshot: Dictionary = move_history.pop_back()
	for i in range(tiles.size()):
		tiles[i].pet_id = snapshot.tiles[i][0]
		tiles[i].removed = snapshot.tiles[i][1]
		tiles[i].liberated = snapshot.tiles[i][2]
	combo_element = snapshot.element
	combo_count = snapshot.combo
	protection = snapshot.protection
	shuffle_remaining = snapshot.shuffle
	shuffle_sequence = snapshot.get("shuffle_sequence", 0)
	undo_remaining -= 1
	selected_id = -1
	hinted_ids.clear()
	has_won = false
	has_failed = false
	notice = "已撤回整次操作（图鉴发现保留）"
	_refresh()
	recorder.record("undo", before, _diagnostic(), {})

func shuffle_board() -> void:
	if is_paused or has_won or has_failed or is_resolving:
		return
	deadlock_dismissed = false
	var deadlocked := BoardRules.first_available_pair(tiles, board.tile_size).is_empty()
	var use_protection := deadlocked and protection > 0
	if shuffle_remaining <= 0 and not use_protection:
		return
	var snapshot := _snapshot()
	var before := _diagnostic()
	var shuffle_seed := _next_shuffle_seed()
	if not BoardGenerator.shuffle_remaining(tiles, board.tile_size, shuffle_seed):
		shuffle_sequence = snapshot.shuffle_sequence
		notice = "本次重排失败，未消耗次数"
		_refresh()
		recorder.record("shuffle_failed", before, _diagnostic(), {"seed": shuffle_seed})
		return
	move_history.append(snapshot)
	if use_protection:
		protection -= 1
	else:
		shuffle_remaining -= 1
	combo_count = 0
	combo_element = ""
	selected_id = -1
	hinted_ids.clear()
	notice = "护佑抵扣洗牌" if use_protection else "已重排剩余牌，Combo清零"
	_refresh()
	recorder.record("shuffle", before, _diagnostic(), {"seed": shuffle_seed, "used_protection": use_protection})

func show_hint(record_action: bool = true) -> void:
	if is_paused or has_won or has_failed or (is_resolving and record_action):
		return
	hinted_ids = BoardRules.first_available_pair(tiles, board.tile_size)
	hint_expires_at = Time.get_ticks_msec() + 2300
	if not is_resolving:
		board.refresh(selected_id, hinted_ids)
	if record_action:
		recorder.record("hint", _diagnostic(), _diagnostic(), {"pair": hinted_ids})

func toggle_pause() -> void:
	if is_resolving:
		return
	var before := _diagnostic()
	is_paused = not is_paused
	_refresh()
	recorder.record("pause", before, _diagnostic(), {"paused": is_paused})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: new_game()
			KEY_Z: undo_last_match()
			KEY_H: show_hint()
			KEY_S: shuffle_board()
			KEY_N: next_level()
			KEY_ESCAPE: toggle_pause()
			KEY_F1: toggle_test_panel()

func _process(_delta: float) -> void:
	if not hinted_ids.is_empty() and Time.get_ticks_msec() >= hint_expires_at:
		hinted_ids.clear()
		board.refresh(selected_id, hinted_ids)

func _refresh() -> void:
	var remaining := BoardRules.remaining_count(tiles)
	var won_now := remaining == 0
	if won_now and not has_won and playtest_index < 0:
		unlocked_level = maxi(unlocked_level, mini(level_index + 1, LevelCatalog.LEVELS.size() - 1))
		_save_progress()
	has_won = won_now
	$HUD/Victory.visible = has_won and not victory_dismissed and not is_paused
	if has_won:
		var final_region := level_index == LevelCatalog.LEVELS.size() - 1
		$HUD/Victory/Panel/Title.text = "测试完成" if playtest_index >= 0 else ("山海之旅完成！" if final_region else "恭喜通关！")
		$HUD/Victory/Panel/Details.text = "%s · 已清空%d张牌\n剩余撤回 %d · 洗牌 %d · 护佑 %d" % [PlaytestCatalog.NAMES[playtest_index] if playtest_index >= 0 else LevelCatalog.LEVELS[level_index].region, tiles.size(), undo_remaining, shuffle_remaining, protection]
		$HUD/Victory/Panel/Actions/Next.visible = playtest_index < 0 and not final_region
	var deadlocked := not has_won and BoardRules.first_available_pair(tiles, board.tile_size).is_empty()
	var can_rearrange := BoardGenerator.can_shuffle_remaining(tiles, board.tile_size)
	has_failed = deadlocked and (not can_rearrange or (shuffle_remaining <= 0 and protection <= 0))
	$HUD/Deadlock.visible = deadlocked and not deadlock_dismissed and not is_paused and not is_resolving
	if deadlocked:
		var reason: String = _diagnostic().reason
		$HUD/Deadlock/Panel/Title.text = "暂时没有可配对的牌" if not has_failed else "本局陷入死局"
		var explanation := "同种牌被封锁，可以洗牌重新打开局面。"
		if reason == "no_matching_identities":
			explanation = "剩余牌没有同种伙伴，洗牌也无法补出对子。"
		elif reason == "insufficient_free_positions":
			explanation = "可用牌位不足两个，重排身份也无法打开牌阵。"
		elif reason == "shuffle_resources_exhausted":
			explanation = "仍有匹配牌，但洗牌与护佑已经用尽。"
		$HUD/Deadlock/Panel/Details.text = explanation + "\n可撤回尝试另一种消除顺序。"
		$HUD/Deadlock/Panel/Actions/Shuffle.disabled = has_failed
		$HUD/Deadlock/Panel/Actions/Shuffle.text = "用护佑洗牌" if protection > 0 else "洗牌（%d）" % shuffle_remaining
		$HUD/Deadlock/Panel/Actions/Undo.disabled = move_history.is_empty() or undo_remaining <= 0
	counter_label.text = "剩余 %d / %d" % [remaining, tiles.size()]
	$HUD/Combo.text = "%s ×%d" % [PetCatalog.ELEMENT_NAMES.get(combo_element, "五行"), combo_count]
	$HUD/Resources.text = "撤回 %d  洗牌 %d  护佑 %d\n图鉴 %d / %d" % [undo_remaining, shuffle_remaining, protection, discovered.size(), PetCatalog.IDS.size()]
	$HUD/Notice.text = notice + ("\n存档失败，请检查存储权限" if save_error else "")
	if is_paused:
		feedback_label.text = "已暂停"
	elif has_won:
		feedback_label.text = "测试完成，可重开比较其他路线" if playtest_index >= 0 else "八地区完成！可选关重玩" if level_index == LevelCatalog.LEVELS.size() - 1 else "通关！点击下一地区"
	elif has_failed:
		feedback_label.text = "无法重排出对子 · 请撤回或重开" if not can_rearrange else "洗牌已用尽 · 请撤回或重开"
	else:
		feedback_label.text = "死局 · 请洗牌或撤回" if deadlocked else ""
	$HUD/Pause.text = "继续" if is_paused else "暂停"
	$HUD/Pause.disabled = is_resolving
	$HUD/Next.disabled = not has_won or level_index + 1 >= LevelCatalog.LEVELS.size() or is_paused
	if playtest_index >= 0:
		$HUD/Next.disabled = true
	$HUD/TestPanel/TestHelp.text = "种子 %d\n%s" % [deal_seed, PlaytestCatalog.HELP[playtest_index] if playtest_index >= 0 else "种子留空为随机；填写整数后，R按同一种子重开。"]
	$HUD/TestPanel/DisableSkills.disabled = playtest_index < 0
	$HUD/Undo.disabled = move_history.is_empty() or undo_remaining <= 0 or is_paused
	$HUD/Shuffle.disabled = has_won or has_failed or is_paused or not can_rearrange or (shuffle_remaining <= 0 and not (deadlocked and protection > 0))
	$HUD/Hint.disabled = has_won or has_failed or is_paused
	$HUD/LevelSelect.select(level_index)
	$HUD/LevelSelect.disabled = playtest_index >= 0
	$HUD/Title.text = "山海麻将 · 测试：" + PlaytestCatalog.NAMES[playtest_index] if playtest_index >= 0 else "山海麻将 · " + str(LevelCatalog.LEVELS[level_index].region)
	for i in range(LevelCatalog.LEVELS.size()):
		$HUD/LevelSelect.set_item_disabled(i, i > unlocked_level and not all_regions_unlocked)
	board.visible = not is_paused
	board.refresh(selected_id, hinted_ids)
	_update_collection()

func _on_tile_inspected(index: int, details: Dictionary) -> void:
	if index < 0:
		$HUD/TileInfo.text = "左上数字：层数\n✓ 可选　锁图标：不可选\n悬停或点牌查看封锁原因\n橙框标出阻挡它的牌"
		return
	var tile := tiles[index]
	var reasons: Array[String] = []
	if not details.above.is_empty():
		reasons.append("上方%d张牌压住" % details.above.size())
	if details.sides_locked:
		reasons.append("同层左右封锁")
	var status := "水已解放，可选" if tile.liberated else ("可选" if reasons.is_empty() else "、".join(reasons))
	$HUD/TileInfo.text = "%s · 第%d层\n%s\n橙框：阻挡此牌的牌" % [PetCatalog.name_for(tile.pet_id), tile.layer + 1, status]

func _update_collection() -> void:
	var grid: ItemList = $HUD/CollectionPanel/Grid
	grid.clear()
	for id in PetCatalog.IDS:
		if id in discovered:
			grid.add_item(PetCatalog.name_for(id), PetCatalog.texture_for(id))
		else:
			grid.add_item("？？？", preload("res://assets/pets/default_lock.png"))
	grid.select(collection_selection)
	_on_collection_selected(collection_selection)

func _on_collection_selected(index: int) -> void:
	collection_selection = index
	var id: String = PetCatalog.IDS[index]
	var known := id in discovered
	$HUD/CollectionPanel/Portrait.texture = PetCatalog.texture_for(id) if known else preload("res://assets/pets/default_lock.png")
	$HUD/CollectionPanel/EarthToken.visible = known and id == PetCatalog.EARTH_PLACEHOLDER_ID
	$HUD/CollectionPanel/Details.text = "%s\n元素：%s\n首次发现：%s" % [PetCatalog.name_for(id), PetCatalog.ELEMENT_NAMES[PetCatalog.element_for(id)], first_regions.get(id, "初始伙伴")] if known else "未发现\n亲手消除一对后收录"

func _load_progress() -> void:
	discovered = PetCatalog.BASE_IDS.duplicate()
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	unlocked_level = clampi(int(data.get("unlocked", 0)), 0, LevelCatalog.LEVELS.size() - 1)
	var saved = data.get("discovered", [])
	if saved is Array:
		for id in saved:
			if id in PetCatalog.IDS and id not in discovered:
				discovered.append(id)
	var regions = data.get("regions", {})
	if regions is Dictionary:
		first_regions = regions

func _save_progress() -> void:
	if playtest_index >= 0:
		return
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	save_error = file == null
	if file != null:
		file.store_string(JSON.stringify({"unlocked": unlocked_level, "discovered": discovered, "regions": first_regions}))
		file.close()
		save_error = DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK
