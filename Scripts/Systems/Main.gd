extends Node2D
## Điều phối lượt chơi: chờ map sinh xong -> đặt Player vào điểm xuất phát hợp lệ -> bắt đầu spawn Enemy.
## Gắn script này vào node gốc "Main" của Main.tscn.

## Kéo Sences/Player/Player.tscn vào ô này trong Inspector.
@export var player_scene: PackedScene
## Tỉ lệ hình nhân vật (chỉ phóng/thu hình, không đổi va chạm). Khung hình gốc 128x128 khá to so với ô 32px.
@export var player_visual_scale: Vector2 = Vector2(0.5, 0.5)
## Độ phóng camera (1 = bình thường, 2 = gần gấp đôi).
@export var camera_zoom: Vector2 = Vector2.ONE

@export_group("Level")
## Danh sách level chạy lần lượt (map, Enemy, điểm, Spell trên map, Boss của từng level nằm trong LevelConfig). Hạ Boss level cuối (is_final) thì kết thúc game: màn hình ending + Hall of Fame.
## Điểm của mỗi Enemy đặt trong scene Enemy (score_value).
@export var levels: Array[LevelConfig] = [
	preload("res://Resources/Levels/level_1.tres"),
	preload("res://Resources/Levels/level_2.tres"),
	preload("res://Resources/Levels/level_3.tres"),
	preload("res://Resources/Levels/level_4.tres"),
]

@export_group("Cảm giác chiến đấu")
## Mọi thông số cảm giác và cân bằng chung (hitstop, rung màn hình, hệ số Enemy/Boss, né hoàn hảo...). Mở file này trong Inspector để chỉnh.
@export var tuning: CombatTuning = preload("res://Resources/combat_tuning.tres")
## Hiện nhãn chữ debug cũ (góc trái trên) khi bắt đầu game. Có thể bật/tắt trong game bằng nút "Chữ" hoặc menu tạm dừng.
@export var show_debug_text_on_start: bool = false

@export_group("Debug")
## Kéo Sences/Enemies/Slime.tscn vào đây để thử Enemy.
@export var debug_enemy_scene: PackedScene
## F2 = sinh 1 Enemy.  F3 = bật/tắt lớp phủ debug của map.
## F4 = kiểm tra 300 vị trí spawn rồi sinh 20 Enemy.  K = giết Enemy gần Player nhất.
## T = thử nhặt Spell trùng và đổi trang bị (bộ đếm không được tăng sai).
## L = giả lập Player chết (Spawner phải dừng).  P = tạm dừng / tiếp tục (do GameManager xử lý).
## Y = nhặt ngay Spell kế tiếp trong Spell Pool để thử độ khó.
## F6 = gắn thanh máu Boss thử nghiệm.  F7 = cộng 50 điểm (thử mở cổng Boss).  F8 = dịch chuyển Player tới gần cổng Boss.
## B = vào thẳng phòng Boss.  F1 = bảng đo hiệu năng.
## F9 = chạy kiểm thử tích hợp tự động (10 lần chơi lại + kiểm tra dừng spawn).
## F10 = đo FPS: đo khi ít Enemy, rồi sinh đầy tới giới hạn và đo lại (xem kết quả ở Output).
## (Chơi lại luôn hoạt động, không phụ thuộc mục này: F5 bất kỳ lúc nào, Enter khi đã chết. Phím R dành cho spell_4. Esc = menu tạm dừng.)
@export var debug_keys_enabled: bool = true
## Khoảng cách spawn tối thiểu / tối đa so với Player (pixel). Màn hình rộng 1152 nên 350 là gần mép màn hình.
@export var debug_spawn_min_distance: float = 350.0
@export var debug_spawn_max_distance: float = 800.0

@export_group("Spell")
## Các Spell sẽ được đặt trên map (mỗi Spell 1 viên). Kéo các file trong Resources/Spells/ vào đây.
@export var spell_pool: Array[SpellData] = []
var _library: Array[SpellData] = []  # thư viện spell hiệu ứng, nạp lười từ SaveSystem.LIBRARY_DIR
## Viên Spell chỉ xuất hiện cách Player ít nhất bấy nhiêu pixel.
@export var pickup_min_distance: float = 300.0

@onready var world: MapGenerator = $World
@onready var spawner: EnemySpawner = $EnemySpawner

var player: CharacterBody2D
var _hud_label: Label
var _combat_hud: CombatHUD
var _score_tracker: ScoreTracker
var _pause_menu: PauseMenu
var _inventory: InventoryPanel
var _in_boss_room: bool = false
var _in_hub: bool = false
## true: map đầu tiên vừa sinh xong thì vào sảnh chờ (lượt chơi mới hoặc nạp file lưu) thay vì vào level.
var _pending_hub: bool = false
var _hub: Hub = null
var _encounter: BossEncounter
var _shaker: CameraShaker
var _feel: GameFeel
var _sfx: SfxPlayer
var _stats: DebugStats
var _boss_brain: BossBrain = BossBrain.new()  # sống cả lượt chơi: Boss nhớ người chơi qua các vòng
var _round: int = 1  # số Boss đã hạ + 1 (độ khó Boss tăng theo số này)
var _level_index: int = 0
var _loop: int = 1  # lần thứ mấy đi hết các level
var _themes: Dictionary = {}  # mã theme -> MapTheme (hoặc null = mặc định), tạo một lần
var _transitioning: bool = false
var _ending_shown: bool = false  # màn hình kết thúc game đang mở: chặn phím chơi lại / debug phía sau
var _test_running: bool = false
var _hud_timer: float = 0.0


func _ready() -> void:
	# Phải nối signal TRƯỚC khi gọi generate(), nếu không sẽ lỡ tín hiệu map_ready.
	CombatTuning.set_current(tuning)
	GameSettings.load_into(tuning)  # cài đặt người chơi (rung, hitstop, âm lượng...) ghi đè giá trị mặc định
	SpellSystem.reset()  # lượt chơi mới -> xóa Spell đã thu thập
	_setup_hud()
	_start_session()
	_shaker = CameraShaker.new()
	add_child(_shaker)
	if SfxPlayer.instance == null:
		_sfx = SfxPlayer.new()
		add_child(_sfx)
	_feel = GameFeel.new()
	_feel.shaker = _shaker
	add_child(_feel)
	spawner.enemy_spawned.connect(_feel.bind_enemy)
	SpellSystem.spell_collected.connect(_on_spell_collected_sfx)
	SpellSystem.ultimate_acquired.connect(_on_ultimate_acquired)
	SpellSystem.spell_stored.connect(_on_spell_stored)
	_stats = DebugStats.new()
	add_child(_stats)
	_stats.world = world
	_stats.extra_text = _boss_debug_text
	world.map_ready.connect(_on_map_ready)
	GameManager.run_ended.connect(_on_run_ended_record)
	_begin_level(true)
	world.generate(MapGenerator.Layout.EXPLORE)


func _unhandled_input(event: InputEvent) -> void:
	# Ép kiểu về InputEventKey một lần: ngắn gọn, đúng kiểu, và tránh truy cập thuộc tính không an toàn trên InputEvent.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _ending_shown:
		return
	# Lưu ý: R là phím spell_4 nên không dùng để chơi lại nữa.
	var restart_pressed: bool = key.keycode == KEY_F5
	# Enter chơi lại khi lượt chơi đã kết thúc (Player chết, hoặc kết thúc bằng phím debug L).
	if (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and player != null and not GameManager.is_run_active:
		restart_pressed = true
	if restart_pressed and player != null:
		restart_run()
		return
	if not debug_keys_enabled or player == null:
		return
	match key.keycode:
		KEY_F2:
			_debug_spawn_enemy()
		KEY_F3:
			world.toggle_debug_draw()
		KEY_F4:
			_debug_spawn_stress_test()
		KEY_F9:
			_debug_integration_test()
		KEY_F10:
			_debug_perf_test()
		KEY_K:
			_debug_kill_nearest_enemy()
		KEY_T:
			_debug_spell_test()
		KEY_L:
			GameManager.end_run(&"player_died")  # giả lập Player chết: Spawner phải ngừng sinh Enemy
		KEY_Y:
			_debug_collect_next_spell()
		KEY_F1:
			_stats.toggle()
		KEY_F6:
			_debug_toggle_boss_bar()
		KEY_F7:
			_score_tracker.add_points(50)
		KEY_F8:
			_debug_teleport_to_portal()
		KEY_B:
			_debug_enter_boss_room()


# ---------------------------------------------------------------- Lượt chơi
## Bắt đầu lượt chơi mới: xóa Spell, sinh map mới, hồi sinh và đặt lại Player, spawn lại Enemy.
## (world.generate() phát map_ready -> _on_map_ready lo phần còn lại.)
func restart_run() -> void:
	if _transitioning:
		return
	_close_hub()
	Wallet.reset()
	RelicSystem.reset()
	ComboSystem.reset()
	RunStats.begin_run()
	_pending_hub = true  # lượt mới cũng bắt đầu ở sảnh chờ
	_in_boss_room = false
	_round = 1
	_level_index = 0
	_loop = 1
	_boss_brain.reset()
	_free_encounter()
	if _inventory != null and _inventory.is_open:
		_inventory.close()
	get_tree().paused = false  # chơi lại từ menu tạm dừng
	SpellSystem.reset()
	_score_tracker.reset()
	_begin_level(true)
	world.generate(MapGenerator.Layout.EXPLORE)


func _on_map_ready() -> void:
	if player_scene == null:
		push_error("Main: chưa gán Player Scene trong Inspector.")
		return

	# Tạo Player lần đầu. Các lần sau (map mới) chỉ cần dời vị trí và hồi sinh.
	if player == null or not is_instance_valid(player):
		player = player_scene.instantiate() as CharacterBody2D
		player.add_to_group("player")
		world.get_entities_root().add_child(player)
		_setup_player_visuals()
		_combat_hud.bind_player(player)
		_feel.bind_player(player)
		# Nối signal đúng 1 lần (chỉ khi tạo Player), nên chơi lại nhiều lần cũng không bị nối trùng.
		if player.has_signal("died"):
			player.connect("died", func(): GameManager.end_run(&"player_died"))

	if player.has_method("revive"):
		player.call("revive")
	player.global_position = world.get_player_start_position()
	player.velocity = Vector2.ZERO
	_setup_camera_limits()
	_combat_hud.set_minimap_source(world, player)
	if _pending_hub:
		_pending_hub = false
		_enter_hub()
		return
	if world.get_layout() == MapGenerator.Layout.BOSS_ARENA:
		# Phòng Boss: lượt chơi vẫn tiếp tục (giữ nguyên Spell và điểm), không spawn Enemy thường, không sinh viên Spell.
		MusicPlayer.play_track(&"boss")
		print("[Main] Vào phòng Boss, Player đặt tại ", player.global_position)
		_start_boss_encounter()
		return
	MusicPlayer.play_track(&"explore")
	_bind_portal(world.get_portal())
	_spawn_spell_pickups()
	# Thứ tự quan trọng: map đã sẵn sàng + Player đã đặt -> mới bắt đầu lượt chơi và spawn Enemy.
	GameManager.start_run()
	spawner.start_run(world, player)
	print("[Main] Player đặt tại ", player.global_position)


# ---------------------------------------------------------------- Level
func _current_level() -> LevelConfig:
	return levels[clampi(_level_index, 0, levels.size() - 1)]


func _level_title() -> String:
	var level := _current_level()
	return level.display_name if _loop <= 1 else "%s (VÒNG %d)" % [level.display_name, _loop]


## Chuẩn bị level hiện tại TRƯỚC khi sinh map: giao diện map, loại Enemy/độ khó spawn, mục tiêu điểm, tiêu đề HUD.
## new_run = true: lượt chơi mới (điểm đã reset); false: sang level kế (điểm được giữ, mục tiêu = điểm hiện tại + goal_points).
func _begin_level(_new_run: bool) -> void:
	var level := _current_level()
	if not _themes.has(level.theme_id):
		_themes[level.theme_id] = MapTheme.create(level.theme_id)
	world.set_theme(_themes[level.theme_id])
	spawner.apply_level(level)
	_score_tracker.begin_level(level.goal_points)
	_combat_hud.set_level_title(_level_title())


# ---------------------------------------------------------------- Sảnh chờ, lưu / nạp
## Đầu phiên: xoá ví / relic / combo cho lượt mới, hoặc nạp file lưu nếu menu chính bấm "Tiếp tục". Luôn bắt đầu ở sảnh chờ.
func _start_session() -> void:
	Wallet.reset()
	RelicSystem.reset()
	ComboSystem.reset()
	RunStats.begin_run()
	_pending_hub = true
	if not SaveSystem.continue_requested:
		return
	SaveSystem.continue_requested = false
	var data := SaveSystem.read()
	if data.is_empty():
		return
	Wallet.set_gold(int(data.get("gold", 0)))
	RelicSystem.load_state(data.get("relics", []), int(data.get("bosses_defeated", 0)))
	SaveSystem.apply_spells(data.get("spells", {}))
	_level_index = clampi(int(data.get("level_index", 0)), 0, levels.size() - 1)
	_loop = maxi(int(data.get("loop", 1)), 1)
	_round = maxi(int(data.get("round", 1)), 1)
	_score_tracker.score = int(data.get("score", 0))
	RunStats.player_name = RunStats.sanitize_name(String(data.get("player_name", RunStats.player_name)))
	RunStats.load_dict(data.get("run", {}))


func _enter_hub() -> void:
	MusicPlayer.play_track(&"hub")
	_in_boss_room = false
	spawner.stop()
	_clear_field()
	ComboSystem.reset()
	_close_hub()
	_in_hub = true  # đặt SAU _close_hub() (hàm đó xoá cờ); thiếu dòng này thì cổng sảnh không dẫn vào level
	_hub = Hub.new()
	_hub.setup(player, _level_title())
	add_child(_hub)
	_hub.leave_requested.connect(_on_hub_leave_requested)
	_hub.save_requested.connect(_on_save_requested)
	player.global_position = _hub.get_spawn_position()
	player.velocity = Vector2.ZERO
	if player.has_method("revive"):
		player.call("revive")  # về sảnh là đầy máu
	_setup_camera_limits(_hub.get_camera_rect())
	_combat_hud.set_hub_mode(true)
	_combat_hud.set_portal(_hub.get_portal())
	_pause_menu.set_save_available(true)
	GameManager.start_run()  # để Tab (kho spell) và Esc (tạm dừng) hoạt động ở sảnh


func _close_hub() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.queue_free()
	_hub = null
	_in_hub = false
	if _combat_hud != null:
		_combat_hud.set_hub_mode(false)
	if _pause_menu != null:
		_pause_menu.set_save_available(false)


## Xoá mọi thứ còn lại trên map chiến đấu (Enemy, đạn, viên spell, viên máu, vàng) khi rời map.
func _clear_field() -> void:
	for group_name in [&"enemies", &"enemy_attacks", &"spell_pickups", &"health_pickups", &"gold_pickups"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.queue_free()


func _on_hub_leave_requested() -> void:
	if _transitioning or not _in_hub or player == null:
		return
	_transitioning = true
	SfxPlayer.play_sfx(&"portal")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _combat_hud.fade_to(1.0, 0.4)
	_close_hub()
	_begin_level(false)
	world.generate(MapGenerator.Layout.EXPLORE)  # phát map_ready -> _on_map_ready đặt Player, spawn Enemy
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await _combat_hud.fade_to(0.0, 0.5)
	_combat_hud.show_banner(_level_title(), "Cần %d điểm để mở cổng Boss (hiện có %d)" % [_score_tracker.score_goal, _score_tracker.score], 3.5)
	_transitioning = false


func _on_save_requested() -> void:
	if not _in_hub:
		return
	SfxPlayer.play_sfx(&"save")
	var relic_ids: Array[String] = []
	for id in RelicSystem.get_owned_ids():
		relic_ids.append(String(id))
	var data := {
		"level_index": _level_index,
		"loop": _loop,
		"round": _round,
		"score": _score_tracker.score,
		"gold": Wallet.gold,
		"relics": relic_ids,
		"bosses_defeated": RelicSystem.bosses_defeated,
		"spells": SaveSystem.capture_spells(),
		"player_name": RunStats.player_name,
		"run": RunStats.to_dict(),
	}
	if SaveSystem.write(data):
		_combat_hud.show_toast("Đã lưu tiến trình", 2.5)
		if _hub != null and is_instance_valid(_hub) and _hub.panel.is_open:
			_hub.panel.show_message("Đã lưu tiến trình. Menu chính sẽ có nút \"Tiếp tục\".")
	else:
		_combat_hud.show_toast("Không lưu được file", 3.0)


# ---------------------------------------------------------------- Hall of Fame, kết thúc game
func _owned_relic_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in RelicSystem.get_owned_ids():
		ids.append(String(id))
	return ids


## Ghi lượt chơi vào Hall of Fame (một lần mỗi lượt). Trả về {"id", "rank", "total"} hoặc {} nếu đã ghi rồi.
func _record_run(completed: bool) -> Dictionary:
	if RunStats.recorded:
		return {}
	RunStats.recorded = true
	var entry := RunStats.make_entry(_score_tracker.score, completed, String(_current_level().id), _owned_relic_ids())
	var result := HallOfFame.submit_run(entry)
	result["entry"] = entry
	return result


## Player chết: ghi Hall of Fame và hiện hạng ở màn hình chết.
func _on_run_ended_record(reason: StringName) -> void:
	if reason != &"player_died":
		return
	var result := _record_run(false)
	if result.is_empty():
		return
	_combat_hud.set_death_rank_text("Hạng trong Hall of Fame: #%d / %d" % [int(result["rank"]), int(result["total"])])


## Hạ xong Boss cuối của level cuối: ghi Hall of Fame (thắng game), xoá file lưu và chiếu màn hình kết thúc.
func _on_game_completed() -> void:
	MusicPlayer.play_track(&"ending", 2.0)
	if _transitioning:
		return
	_transitioning = true
	RunStats.levels_cleared += 1
	var result := _record_run(true)
	SaveSystem.delete_save()
	if result.is_empty():
		result = {"id": -1, "rank": 0, "total": HallOfFame.get_count(), "entry": RunStats.make_entry(_score_tracker.score, true, String(_current_level().id), _owned_relic_ids())}
	var ending := EndingScreen.new()
	add_child(ending)
	ending.restart_requested.connect(_on_ending_restart.bind(ending))
	ending.show_ending(result["entry"], result)
	_ending_shown = true
	GameManager.is_run_active = false  # để Esc không mở/đóng menu tạm dừng phía sau màn hình kết thúc
	get_tree().paused = true


## Bấm "Chơi lại - giữ tên" ở màn hình kết thúc: đóng màn hình, mở khóa rồi bắt đầu lượt mới.
func _on_ending_restart(ending: EndingScreen) -> void:
	if is_instance_valid(ending):
		ending.queue_free()
	_ending_shown = false
	_transitioning = false
	get_tree().paused = false
	restart_run()


# ---------------------------------------------------------------- Cổng Boss
func _bind_portal(portal: BossPortal) -> void:
	if portal == null:
		return
	portal.activated.connect(_on_portal_activated)
	portal.locked_touched.connect(_on_portal_locked_touched)
	_combat_hud.set_portal(portal)
	if _score_tracker.goal_unlocked:
		portal.unlock()


## Đạt đủ điểm: mở cổng.
func _on_goal_reached() -> void:
	var portal := world.get_portal()
	if portal != null:
		portal.unlock()
	SfxPlayer.play_sfx(&"goal")
	_combat_hud.show_toast("Cổng Boss đã mở! Đi theo mũi tên vàng", 4.0)


func _on_portal_locked_touched() -> void:
	_combat_hud.show_toast("Cổng đang khóa: cần %d điểm (hiện có %d)" % [_score_tracker.score_goal, _score_tracker.score], 3.0)


## Player đứng đủ lâu trong cổng đã mở: tối màn hình, dựng phòng Boss, sáng lại.
func _on_portal_activated() -> void:
	if _transitioning or _in_boss_room or player == null:
		return
	_transitioning = true
	SfxPlayer.play_sfx(&"portal")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _combat_hud.fade_to(1.0, 0.4)
	spawner.stop()
	_in_boss_room = true
	world.generate(MapGenerator.Layout.BOSS_ARENA)  # phát map_ready -> _on_map_ready đặt Player vào phòng Boss
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await _combat_hud.fade_to(0.0, 0.5)
	_transitioning = false


# ---------------------------------------------------------------- Trận Boss
func _start_boss_encounter() -> void:
	_free_encounter()
	_encounter = BossEncounter.new()
	add_child(_encounter)
	_encounter.setup(world, player, _combat_hud, _shaker, _score_tracker, _current_level(), _round, _boss_brain, _feel)
	_encounter.exit_requested.connect(_on_boss_exit_requested)
	_encounter.all_bosses_defeated.connect(_on_game_completed)
	_encounter.start()


func _free_encounter() -> void:
	if _encounter != null and is_instance_valid(_encounter):
		_encounter.queue_free()
	_encounter = null


## Player bước vào cổng thoát (đã mở sau khi hạ Boss): sang LEVEL KẾ (hết level cuối thì quay về level đầu, vòng mới).
## Giữ nguyên Spell và điểm, máu hồi đầy, mục tiêu điểm = điểm hiện tại + goal_points của level mới.
func _on_boss_exit_requested() -> void:
	if _transitioning or not _in_boss_room or player == null:
		return
	_transitioning = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _combat_hud.fade_to(1.0, 0.5)
	_round += 1
	RunStats.levels_cleared += 1
	_level_index = mini(_level_index + 1, levels.size() - 1)  # level cuối (is_final) không có cổng thoát nên không bao giờ vượt quá
	_in_boss_room = false
	_free_encounter()
	_enter_hub()  # sau mỗi Boss người chơi về sảnh chờ: mua relic, lưu game, rồi vào cổng sang level kế
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await _combat_hud.fade_to(0.0, 0.5)
	_combat_hud.show_banner("SẢNH CHỜ", "Tiếp theo: %s. Nói chuyện với NPC bằng F, rồi vào cổng phía bắc" % _level_title(), 4.0)
	_transitioning = false


func _setup_player_visuals() -> void:
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.scale = player_visual_scale


func _setup_camera_limits(rect_override: Rect2 = Rect2()) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.zoom = camera_zoom
	_shaker.camera = cam
	var origin := world.global_position
	var size := world.get_map_pixel_size()
	if rect_override.size != Vector2.ZERO:  # sảnh chờ: giới hạn camera theo phòng sảnh
		origin = rect_override.position
		size = rect_override.size
	cam.limit_left = int(origin.x)
	cam.limit_top = int(origin.y)
	cam.limit_right = int(origin.x + size.x)
	cam.limit_bottom = int(origin.y + size.y)
	cam.reset_smoothing()  # đặt Player ở chỗ mới thì camera nhảy tới ngay, không "trượt" từ chỗ cũ


# ---------------------------------------------------------------- Spell
## Đặt các Spell chưa có trong spell_pool thành viên trên map (tối đa level.max_spells_on_map viên, chọn ngẫu nhiên; -1 = hết),
## ở vị trí hợp lệ cách Player đủ xa.
func _spawn_spell_pickups() -> void:
	for old in get_tree().get_nodes_in_group("spell_pickups"):
		old.remove_from_group("spell_pickups")
		old.queue_free()
	for old_drop in get_tree().get_nodes_in_group("health_pickups"):
		old_drop.queue_free()
	var candidates: Array[SpellData] = []
	for spell in spell_pool:
		if not SpellSystem.has_spell(spell.id):  # vòng chơi sau: không rải lại Spell đã có
			candidates.append(spell)
	candidates.shuffle()
	var limit := _current_level().max_spells_on_map
	if limit >= 0 and candidates.size() > limit:
		candidates.resize(limit)
	candidates.append_array(_pick_library_spells(_current_level().library_spells_on_map))
	for spell in candidates:
		var pos := world.get_spawn_position(player.global_position, pickup_min_distance)
		if pos == MapGenerator.NO_SPAWN:
			push_warning("Main: không tìm được chỗ đặt Spell '%s'." % spell.id)
			continue
		var pickup := SpellPickup.new()
		pickup.spell = spell
		world.get_entities_root().add_child(pickup)
		pickup.global_position = pos


## Chọn ngẫu nhiên count Spell chưa sở hữu từ thư viện hiệu ứng (đọc thư mục LIBRARY_DIR một lần rồi lưu đệm).
func _pick_library_spells(count: int) -> Array[SpellData]:
	var picked: Array[SpellData] = []
	if count <= 0:
		return picked
	_load_library()
	var pool: Array[SpellData] = []
	for spell in _library:
		if not SpellSystem.has_spell(spell.id):
			pool.append(spell)
	pool.shuffle()
	for i in mini(count, pool.size()):
		picked.append(pool[i])
	return picked


## Nạp thư viện kỹ năng (Resources/Spells/Library/sk_*.tres) một lần rồi lưu đệm.
func _load_library() -> void:
	if not _library.is_empty():
		return
	var names: Array[String] = []
	for f in DirAccess.get_files_at(SaveSystem.LIBRARY_DIR):
		var file_name := f.trim_suffix(".remap")
		if file_name.begins_with("sk_") and file_name.ends_with(".tres") and not names.has(file_name):  # bỏ qua fx_*.tres cũ của Phase 16 nếu còn sót
			names.append(file_name)
	names.sort()
	for file_name in names:
		var spell := load(SaveSystem.LIBRARY_DIR + file_name) as SpellData
		if spell != null:
			_library.append(spell)


# ---------------------------------------------------------------- HUD
func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Nhãn chữ debug cũ: đặt dưới hàng nút của HUD, bật/tắt bằng nút "Chữ" hoặc menu tạm dừng.
	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 46)
	_style_label(_hud_label, 16)
	_hud_label.visible = show_debug_text_on_start
	layer.add_child(_hud_label)

	# Bảng điểm: cộng điểm khi hạ gục Enemy, đủ điểm thì mở cổng Boss.
	_score_tracker = ScoreTracker.new()
	_score_tracker.score_goal = levels[0].goal_points if not levels.is_empty() else 500
	add_child(_score_tracker)
	_score_tracker.bind_spawner(spawner)
	_score_tracker.goal_reached.connect(_on_goal_reached)
	_score_tracker.kill_recorded.connect(func(_n: String, _p: int) -> void: RunStats.kills += 1)

	# Giao diện chiến đấu thật (máu, thanh kỹ năng, bảng điểm, màn hình chết...).
	_combat_hud = CombatHUD.new()
	_combat_hud.debug_text_visible = show_debug_text_on_start
	add_child(_combat_hud)
	_combat_hud.restart_requested.connect(restart_run)
	_combat_hud.pause_requested.connect(GameManager.toggle_pause)
	_combat_hud.debug_text_toggled.connect(func(is_shown: bool) -> void: _hud_label.visible = is_shown)
	_combat_hud.bind_score_tracker(_score_tracker)

	# Menu tạm dừng (Esc / nút II / phím P).
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.setup(_combat_hud, _score_tracker)
	_pause_menu.restart_requested.connect(restart_run)
	_pause_menu.save_requested.connect(_on_save_requested)
	_pause_menu.debug_text_toggle_requested.connect(_combat_hud.toggle_debug_text)

	# Kho spell (Tab): kéo thả spell vào các ô kỹ năng.
	_inventory = InventoryPanel.new()
	add_child(_inventory)

	SpellSystem.spell_collected.connect(_on_spell_changed)
	SpellSystem.spell_equipped.connect(_on_spell_changed)
	SpellSystem.spell_unequipped.connect(_on_spell_changed)
	SpellSystem.collection_reset.connect(_update_hud)
	_update_hud()


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)


func _on_spell_changed(_a = null, _b = null) -> void:
	_update_hud()


func _process(delta: float) -> void:
	# Chỉ cập nhật HUD 10 lần/giây thay vì mỗi frame.
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_update_hud()


func _update_hud() -> void:
	var hp_text := ""
	if player != null and is_instance_valid(player):
		hp_text = "  |  HP: %d / %d" % [int(player.get("health")), int(player.get("max_health"))]
	_hud_label.text = "Spell đã thu thập: %d  |  đang trang bị: %d%s\nEnemy: %d / mục tiêu %d (tối đa %d)  |  nhịp spawn: %.2fs\nFPS: %d  |  Node: %d" % [
		SpellSystem.get_collected_count(), SpellSystem.get_equipped_count(), hp_text,
		spawner.get_enemy_count(), spawner.get_target_enemy_count(), spawner.max_enemies,
		spawner.get_spawn_interval(),
		int(Engine.get_frames_per_second()), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	var boss_text := _boss_debug_text()
	if not boss_text.is_empty():
		_hud_label.text += "\n" + boss_text


# ---------------------------------------------------------------- Debug
## F9: chơi lại 10 lần liên tiếp, mỗi lần kiểm tra các điều kiện tích hợp; rồi kiểm tra Spawner dừng khi hết lượt.
func _debug_integration_test() -> void:
	if _test_running:
		return
	_test_running = true
	var runs := 10
	var failed_runs := 0
	print("[Test] Bắt đầu kiểm thử tích hợp (%d lần chơi lại)..." % runs)
	for i in runs:
		restart_run()
		await get_tree().process_frame  # chờ node cũ được giải phóng
		var problems: Array[String] = []
		if not world.map_valid:
			problems.append("map không hợp lệ")
		if not world.is_spawnable(player.global_position):
			problems.append("Player không đứng trên ô hợp lệ")
		if get_tree().get_nodes_in_group("player").size() != 1:
			problems.append("số Player khác 1")
		if bool(player.get("is_dead")):
			problems.append("Player chưa hồi sinh")
		if not GameManager.is_run_active:
			problems.append("lượt chơi chưa bắt đầu")
		if SpellSystem.get_collected_count() != 0:
			problems.append("Spell chưa được xóa")
		var enemies := spawner.get_enemy_count()
		if enemies < 1 or enemies > spawner.get_target_enemy_count():
			problems.append("số Enemy ban đầu sai (%d, mục tiêu %d)" % [enemies, spawner.get_target_enemy_count()])
		var pickups := get_tree().get_nodes_in_group("spell_pickups").size()
		var expected_pickups := spell_pool.size() + _current_level().library_spells_on_map  # + spell thư viện (tối đa)
		if _current_level().max_spells_on_map >= 0:
			expected_pickups = mini(expected_pickups, _current_level().max_spells_on_map)
		if pickups != expected_pickups:
			problems.append("số viên Spell sai (%d / %d)" % [pickups, expected_pickups])
		if problems.is_empty():
			print("[Test] Lần %d: OK (Enemy %d, Spell viên %d)" % [i + 1, enemies, pickups])
		else:
			failed_runs += 1
			print("[Test] Lần %d: LỖI -> %s" % [i + 1, ", ".join(problems)])

	# Spawner phải dừng hẳn khi lượt chơi kết thúc.
	var before := spawner.get_enemy_count()
	_debug_kill_nearest_enemy()  # tạo chỗ thiếu để Spawner (nếu còn chạy) sẽ bù Enemy
	GameManager.end_run(&"test")
	await get_tree().create_timer(spawner.get_spawn_interval() * 2.5).timeout
	var after := spawner.get_enemy_count()
	if after == before - 1:
		print("[Test] Dừng spawn khi hết lượt: OK (%d -> %d)" % [before, after])
	else:
		failed_runs += 1
		print("[Test] Dừng spawn khi hết lượt: LỖI (%d -> %d, đáng lẽ %d)" % [before, after, before - 1])

	restart_run()
	print("[Test] KẾT QUẢ: %s" % ("TẤT CẢ ĐẠT" if failed_runs == 0 else "%d mục LỖI" % failed_runs))
	_test_running = false


## F10: đo FPS khi ít Enemy (cơ sở) rồi khi đầy Enemy (tối đa). Máu Player được hồi liên tục để không chết giữa chừng.
func _debug_perf_test() -> void:
	if _test_running:
		return
	_test_running = true
	print("[Perf] Bắt đầu đo (khoảng 8 giây, đừng bấm phím)...")
	var base := await _sample_fps(3.0)
	var enemies_before := spawner.get_enemy_count()
	spawner.spawn_now(spawner.max_enemies - enemies_before)
	await get_tree().process_frame
	var full := await _sample_fps(5.0)
	print("[Perf] Ít Enemy (%d):  FPS trung bình %.0f | thấp nhất %.0f" % [enemies_before, base["avg"], base["min"]])
	print("[Perf] Nhiều Enemy (%d): FPS trung bình %.0f | thấp nhất %.0f" % [spawner.get_enemy_count(), full["avg"], full["min"]])
	print("[Perf] Số node: %d | vật thể vật lý 2D đang hoạt động: %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))])
	_test_running = false


func _sample_fps(seconds: float) -> Dictionary:
	var elapsed := 0.0
	var frames := 0
	var lowest := INF
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		frames += 1
		lowest = minf(lowest, Engine.get_frames_per_second())
		if player != null and is_instance_valid(player):
			player.call("heal", 9999.0)
	return {"avg": frames / maxf(elapsed, 0.001), "min": lowest}


## T = thử nhặt trùng + đổi trang bị: bộ đếm KHÔNG được tăng sai.
func _debug_spell_test() -> void:
	if spell_pool.is_empty():
		push_warning("Main: Spell Pool đang trống.")
		return
	var s: SpellData = spell_pool[0]
	var before := SpellSystem.get_collected_count()
	var r1 := SpellSystem.collect_spell(s)
	var r2 := SpellSystem.collect_spell(s)  # nhặt lại lần nữa: phải trả về false
	SpellSystem.unequip(0)
	SpellSystem.equip(0, s.id)
	print("[Debug] Spell '%s': nhặt lần 1 = %s | nhặt lại = %s | đếm %d -> %d (chỉ được +1 nếu Spell này chưa có)" % [s.id, r1, r2, before, SpellSystem.get_collected_count()])


## Y = nhặt ngay Spell kế tiếp trong Spell Pool (không cần đi tới viên Spell) để thử độ khó nhanh.
func _debug_collect_next_spell() -> void:
	for s in spell_pool:
		if SpellSystem.collect_spell(s):
			return
	# Hết Spell trong pool: nhặt tiếp các kỹ năng trong thư viện (Magma Stone, Sonic Flares, Inferno Dash Puff, ...).
	_load_library()
	for s in _library:
		if SpellSystem.collect_spell(s):
			print("[Debug] Đã thu thập kỹ năng: ", s.display_name)
			return
	print("[Debug] Đã thu thập hết Spell trong Spell Pool và thư viện kỹ năng.")


func _debug_spawn_enemy() -> void:
	if debug_enemy_scene == null:
		push_warning("Main: chưa gán Debug Enemy Scene.")
		return
	var pos := world.get_spawn_position(player.global_position, debug_spawn_min_distance, debug_spawn_max_distance)
	if pos == MapGenerator.NO_SPAWN:
		push_warning("Main: không có vị trí spawn hợp lệ trong khoảng cách đã chọn.")
		return
	var enemy := debug_enemy_scene.instantiate() as Enemy
	if enemy == null:
		push_error("Main: scene này chưa gắn script Enemy.gd.")
		return
	enemy.global_position = pos
	enemy.died.connect(_on_debug_enemy_died)
	world.get_entities_root().add_child(enemy)
	print("[Debug] Enemy sống: ", get_tree().get_nodes_in_group("enemies").size())


## Lấy 300 vị trí spawn và kiểm tra từng vị trí (hợp lệ + đủ xa Player), rồi sinh 20 Enemy.
func _debug_spawn_stress_test() -> void:
	var total := 300
	var no_spot := 0
	var bad := 0
	for i in total:
		var pos := world.get_spawn_position(player.global_position, debug_spawn_min_distance, debug_spawn_max_distance)
		if pos == MapGenerator.NO_SPAWN:
			no_spot += 1
		elif not world.is_spawnable(pos) or pos.distance_to(player.global_position) < debug_spawn_min_distance - 0.01:
			bad += 1
	print("[Debug] Kiểm tra spawn: %d mẫu | không có chỗ: %d | SAI: %d | ô spawn của map: %d" % [total, no_spot, bad, world.get_spawn_cell_count()])
	for i in 20:
		_debug_spawn_enemy()


func _on_spell_collected_sfx(_spell: SpellData, _total: int) -> void:
	SfxPlayer.play_sfx(&"pickup")


## Nhặt Ultimate (rơi ra sau Boss level 1): luôn nằm ở ô R, thanh mana xuất hiện.
func _on_ultimate_acquired(spell: SpellData) -> void:
	SfxPlayer.play_sfx(&"ultimate_get")
	_combat_hud.show_banner(spell.display_name.to_upper(), "Phím R. Đánh Enemy để nạp mana; đủ 100 mana: R thành ULTIMATE", 5.0)


func _on_spell_stored(spell: SpellData) -> void:
	_combat_hud.show_toast("Nhặt %s: 3 ô đã đầy. Bấm Tab để kéo vào ô muốn dùng" % spell.display_name, 6.0)


## Dòng debug về Boss (giai đoạn, đòn, những gì Boss đã học). Rỗng nếu không có Boss.
func _boss_debug_text() -> String:
	if _encounter != null and is_instance_valid(_encounter) and _encounter.boss != null and is_instance_valid(_encounter.boss):
		return _encounter.boss.get_debug_text()
	return ""


## B: vào thẳng phòng Boss (kiểm thử trận Boss không cần đủ điểm).
func _debug_enter_boss_room() -> void:
	if not _in_boss_room and not _transitioning:
		_on_portal_activated()


## F8: dịch chuyển Player tới ngay phía dưới cổng Boss để thử mở cổng.
func _debug_teleport_to_portal() -> void:
	var portal := world.get_portal()
	if portal == null or player == null:
		return
	player.global_position = portal.global_position + Vector2(0.0, 90.0)


## F6: gắn thanh máu Boss vào Enemy gần nhất để thử giao diện (Boss thật sẽ có ở Phase 7). Bấm lần nữa để tắt.
func _debug_toggle_boss_bar() -> void:
	if _combat_hud == null:
		return
	var nearest: Enemy = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := player.global_position.distance_squared_to(e.global_position)
		if d < best:
			best = d
			nearest = e as Enemy
	if nearest == null:
		return
	if _combat_hud.get_boss() == nearest:
		_combat_hud.hide_boss_bar()
	else:
		_combat_hud.show_boss_bar(nearest, "BOSS THỬ NGHIỆM")


func _debug_kill_nearest_enemy() -> void:
	var nearest: Enemy = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := player.global_position.distance_squared_to(e.global_position)
		if d < best:
			best = d
			nearest = e as Enemy
	if nearest != null:
		nearest.take_damage(9999.0)


func _on_debug_enemy_died(_enemy: Enemy) -> void:
	# Enemy rời nhóm "enemies" ngay khi chết (trước khi animation chết kết thúc) nên số này đã đúng.
	print("[Debug] Enemy chết. Còn sống: ", get_tree().get_nodes_in_group("enemies").size())
