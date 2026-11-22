class_name BossEncounter
extends Node
## Điều phối MỘT trận Boss trong phòng Boss (Main tạo node này mỗi lần vào phòng):
##  1. Khóa phòng: đặt CỔNG THOÁT (khóa) ở phía bắc đấu trường; chạm vào chỉ hiện thông báo "bị khóa".
##  2. Giới thiệu: Boss xuất hiện ở giữa nhưng miễn nhiễm và đứng yên trong intro_time giây (banner tên Boss, rung màn hình, thanh máu Boss).
##  3. Chiến đấu: Boss tự đánh (xem Boss.gd). Đổi giai đoạn -> banner + rung màn hình.
##  4. Chiến thắng: xóa đạn còn bay, cộng điểm thưởng của level, hồi đầy máu, rơi phần thưởng của level (Ultimate ở level 1, nếu chưa có), MỞ cổng thoát.
##  5. Player bước vào cổng thoát đã mở -> phát exit_requested (Main chuyển sang vòng chơi mới).
## Level có boss_sequence (level 4): Boss thứ N chuyển sang giai đoạn 2 thì Boss thứ N+1 xuất hiện NGAY để chi viện (nhiều Boss cùng lúc).
## Hạ một Boss: không hồi đầy máu, Boss rơi 3-5 viên máu ngẫu nhiên quanh xác (LevelConfig.boss_drop_hearts_min/max). Hạ hết tất cả Boss mới thắng.
## Level is_final: sau Boss cuối không có cổng thoát mà phát all_bosses_defeated (Main chiếu màn hình kết thúc game).
## Độ khó tăng theo vòng chơi (round_number): máu và sát thương Boss tăng nhẹ mỗi vòng.

## Boss đã bị hạ (sau khi phần thưởng và cổng thoát đã xử lý xong).
signal boss_defeated
## Player bước vào cổng thoát đã mở.
signal exit_requested
## Level cuối: Boss cuối cùng đã bị hạ (sau vài giây cho người chơi thấy cảnh Boss chết).
signal all_bosses_defeated

@export var intro_time: float = 2.6
## Boss chi viện xuất hiện giữa trận: thời gian miễn nhiễm/đứng yên ngắn hơn Boss đầu.
@export var support_intro_time: float = 1.6
## Nghỉ giữa hai Boss trong chuỗi Boss (giây) và tỉ lệ máu hồi cho Player giữa hai Boss.
@export var between_bosses_time: float = 4.5
@export_range(0.0, 1.0, 0.05) var between_bosses_heal: float = 0.5
## Nghỉ sau Boss cuối của level cuối trước khi chiếu màn hình kết thúc (giây).
@export var ending_delay: float = 4.0
## Mỗi vòng sau, máu Boss tăng thêm tỉ lệ này (0.4 = +40% mỗi vòng).
@export var health_scale_per_round: float = 0.4
@export var damage_scale_per_round: float = 0.2

var boss: Boss = null
var exit_portal: BossPortal = null

var _world: MapGenerator
var _player: Node2D
var _hud: CombatHUD
var _shaker: CameraShaker
var _tracker: ScoreTracker
var _level: LevelConfig = null
var _boss_scenes: Array[PackedScene] = []
var _boss_index: int = 0  # số Boss đã xuất hiện (cũng là chỉ số Boss kế tiếp)
var _alive_bosses: Array[Boss] = []
var _pending_timer: Timer = null
var _ending_pending: bool = false
var _round_number: int = 1
var _brain: BossBrain = null
var _feel: GameFeel = null
var _finished: bool = false


func setup(world: MapGenerator, player: Node2D, hud: CombatHUD, shaker: CameraShaker, tracker: ScoreTracker,
		level: LevelConfig, round_number: int, brain: BossBrain = null, feel: GameFeel = null) -> void:
	_world = world
	_player = player
	_hud = hud
	_shaker = shaker
	_tracker = tracker
	_level = level
	_boss_scenes = level.get_boss_scenes()
	_round_number = maxi(round_number, 1)
	_brain = brain
	_feel = feel


## Dựng cổng thoát (trừ level cuối), đặt Boss đầu tiên và bắt đầu phần giới thiệu. Gọi sau khi phòng Boss đã sinh xong và Player đã được đặt vào.
func start() -> void:
	if not _level.is_final:
		exit_portal = BossPortal.new()
		exit_portal.setup(64.0)
		_world.add_world_node(exit_portal)
		exit_portal.global_position = _world.get_arena_point(-PI * 0.5, 0.72)  # phía bắc, cách xa chỗ Player xuất hiện
		exit_portal.activated.connect(_on_exit_activated)
		exit_portal.locked_touched.connect(_on_exit_locked)
	_pending_timer = Timer.new()
	_pending_timer.one_shot = true
	_pending_timer.timeout.connect(_on_pending_timeout)
	add_child(_pending_timer)
	_boss_index = 0
	_spawn_boss(0, false)


func _spawn_boss(index: int, support: bool) -> void:
	if index < 0 or index >= _boss_scenes.size() or _boss_scenes[index] == null:
		push_error("BossEncounter: level không có Boss thứ %d." % index)
		return
	var new_boss := _boss_scenes[index].instantiate() as Boss
	if new_boss == null:
		push_error("BossEncounter: boss_scene không có script Boss.gd.")
		return
	_boss_index = index + 1
	boss = new_boss
	new_boss.set_meta("boss_index", index)
	# Điều chỉnh theo level/vòng chơi TRƯỚC khi thêm vào cây (Boss.health lấy từ max_health trong _ready).
	new_boss.max_health = maxf(new_boss.max_health + _level.boss_health_delta, 200.0)
	new_boss.max_health *= 1.0 + health_scale_per_round * float(_round_number - 1)
	new_boss.damage_multiplier = 1.0 + damage_scale_per_round * float(_round_number - 1)
	if _brain != null:
		new_boss.brain = _brain  # Boss nhớ người chơi qua các vòng
	new_boss.configure_arena(_world.get_boss_spawn_position(), _world.get_arena_radius(), _world.get_arena_half_extents())
	_world.get_entities_root().add_child(new_boss)
	var spawn_pos := _world.get_boss_spawn_position()
	if support and _player != null and is_instance_valid(_player):
		# Boss chi viện xuất hiện ở phía đối diện Player (so với tâm đấu trường) để không đè lên người chơi.
		var to_player := _player.global_position - _world.get_boss_spawn_position()
		var angle := to_player.angle() + PI if to_player.length() > 8.0 else randf() * TAU
		spawn_pos = _world.get_arena_point(angle, 0.55)
	new_boss.global_position = spawn_pos
	_alive_bosses.append(new_boss)
	if _feel != null:
		_feel.bind_enemy(new_boss)
		_feel.bind_boss(new_boss)
	if new_boss.has_signal("minion_spawned"):
		new_boss.connect("minion_spawned", _on_minion_spawned)  # Boss triệu hồi đệ tử: gắn phản hồi chiến đấu cho chúng
	new_boss.died.connect(_on_boss_died)
	new_boss.phase_changed.connect(_on_phase_changed.bind(new_boss))
	new_boss.impact.connect(_on_boss_impact)

	_hud.add_boss_bar(new_boss, new_boss.boss_title)  # mỗi Boss đang có mặt một thanh máu (tối đa 3, xếp ngang)
	var order_text := "" if _boss_scenes.size() <= 1 else "BOSS %d / %d - " % [index + 1, _boss_scenes.size()]
	var sub_text := "Phòng đã bị khóa - hãy hạ Boss để thoát" if not _level.is_final else "Hạ cả %d Boss để kết thúc hầm ngục" % _boss_scenes.size()
	if support:
		sub_text = "Boss chi viện xuất hiện!"
	var wait := support_intro_time if support else intro_time
	_hud.show_banner(new_boss.boss_title, order_text + sub_text, wait)
	_shaker.shake(5.0, 0.6)
	# Mỗi Boss một Timer riêng (con của node này) thay vì await để không lỗi khi node bị xóa giữa chừng (chơi lại).
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait
	timer.timeout.connect(_on_intro_finished.bind(new_boss, timer))
	add_child(timer)
	timer.start()


func _on_intro_finished(target: Boss, timer: Timer) -> void:
	timer.queue_free()
	if target != null and is_instance_valid(target) and not target.is_dead:
		target.activate()


func _on_minion_spawned(minion: Node) -> void:
	if _feel != null:
		_feel.bind_enemy(minion)


func _on_phase_changed(phase: int, changed: Boss) -> void:
	_hud.show_banner("GIAI ĐOẠN %d" % phase, "Boss nổi giận!", 2.4)
	_shaker.shake(8.0, 0.7)
	# Chuỗi chi viện: Boss mới nhất chuyển giai đoạn 2 thì Boss kế tiếp xuất hiện ngay.
	if phase >= 2 and is_instance_valid(changed) and int(changed.get_meta("boss_index", -1)) == _boss_index - 1 and _boss_index < _boss_scenes.size():
		_spawn_boss.call_deferred(_boss_index, true)


func _on_boss_impact(strength: float) -> void:
	_shaker.shake(strength, 0.35)


## Boss chết ngay trong callback va chạm của đạn (đang xử lý vật lý) nên mọi việc tạo node vật lý (viên Spell, viên máu) phải dời sang cuối frame.
func _on_boss_died(dead: Enemy = null) -> void:
	_finish_victory.call_deferred(dead)


func _finish_victory(dead: Enemy = null) -> void:
	for i in range(_alive_bosses.size() - 1, -1, -1):  # dọn Boss đã bị xóa khỏi cây hoặc đã chết
		if not is_instance_valid(_alive_bosses[i]) or _alive_bosses[i].is_dead:
			_alive_bosses.remove_at(i)
	var dead_boss: Boss = null
	if dead != null and is_instance_valid(dead):
		dead_boss = dead as Boss
	if dead_boss != null:
		_alive_bosses.erase(dead_boss)
		_hud.remove_boss_bar(dead_boss)
	_clear_attacks()
	var position := _world.get_boss_spawn_position()
	var boss_name := ""
	if dead_boss != null:
		position = dead_boss.global_position
		boss_name = dead_boss.enemy_name
	var bonus := int(round(float(_level.boss_bonus_points) / float(maxi(_boss_scenes.size(), 1))))
	if bonus > 0:
		_tracker.add_points(bonus, boss_name)  # kèm tên Boss nên ScoreTracker.kill_recorded đã tính 1 lần hạ gục vào RunStats.kills
	else:
		RunStats.kills += 1
	RunStats.bosses_defeated += 1
	RelicSystem.register_boss_defeated()  # mở thêm hàng của Relic Merchant ở sảnh
	_shaker.shake(8.0, 0.8)
	SfxPlayer.play_sfx(&"victory")
	var player_ok := _player != null and is_instance_valid(_player) and _player.has_method("heal")
	if _boss_scenes.size() > 1:
		_drop_hearts(position)
		# Còn Boss đang sống: thanh máu chuyển sang Boss đó. Boss kế chưa xuất hiện (bị hạ trước giai đoạn 2) thì gọi ngay.
		if not _alive_bosses.is_empty():
			boss = _alive_bosses[0]
			_hud.show_banner("BOSS ĐÃ BỊ HẠ", "Còn %d Boss - máu rơi quanh xác Boss" % _alive_bosses.size(), 2.5)
			return
		if _boss_index < _boss_scenes.size():
			_hud.show_banner("BOSS ĐÃ BỊ HẠ", "Boss kế tiếp xuất hiện!", 2.5)
			_spawn_boss(_boss_index, true)
			return
	if _finished:
		return
	_finished = true
	_hud.hide_boss_bar()
	if player_ok and not _level.is_final:
		_player.call("heal", 9999.0)
	# Level cuối: không có cổng thoát, chiếu ending sau một nhịp để người chơi thấy Boss gục.
	if _level.is_final:
		_hud.show_banner("TẤT CẢ BOSS ĐÃ BỊ HẠ", "Hầm ngục chìm vào im lặng...", ending_delay)
		_ending_pending = true
		_pending_timer.start(ending_delay)
		boss_defeated.emit()
		return
	# Phần thưởng của level: một viên Spell (Ultimate màu đỏ ở level 1) nếu Player chưa có.
	var reward_text := "Máu được hồi đầy - vào cổng phía bắc để đi tiếp"
	var reward := _level.reward_spell
	if reward != null and not SpellSystem.has_spell(reward.id):
		var pickup := SpellPickup.new()
		pickup.spell = reward
		pickup.radius = 26.0
		pickup.reward = true
		_world.get_entities_root().add_child(pickup)
		pickup.global_position = position + Vector2(0.0, 70.0)
		reward_text = "Nhặt biểu tượng phát sáng để nhận %s, rồi vào cổng phía bắc" % reward.display_name
	if exit_portal != null and is_instance_valid(exit_portal):
		exit_portal.unlock()
	_hud.show_banner("BOSS ĐÃ BỊ HẠ GỤC", reward_text, 4.5)
	boss_defeated.emit()


## Hết giờ nghỉ sau Boss cuối của level cuối: chiếu màn hình kết thúc game.
func _on_pending_timeout() -> void:
	if _ending_pending:
		_ending_pending = false
		all_bosses_defeated.emit()


## Boss rơi ngẫu nhiên boss_drop_hearts_min..max viên máu rải quanh vị trí chết (không hồi đầy máu Player).
func _drop_hearts(center: Vector2) -> void:
	var count := randi_range(_level.boss_drop_hearts_min, maxi(_level.boss_drop_hearts_min, _level.boss_drop_hearts_max))
	var tuning := CombatTuning.current()
	var parent_node := _world.get_entities_root()
	for i in count:
		var pickup := HealthPickup.new()
		pickup.heal_amount = tuning.hp_drop_heal
		pickup.lifetime = 40.0
		var offset := Vector2.from_angle(TAU * (float(i) + randf() * 0.6) / float(count)) * randf_range(50.0, 110.0)
		parent_node.add_child(pickup)
		pickup.global_position = center + offset


func _clear_attacks() -> void:
	for node in get_tree().get_nodes_in_group("enemy_attacks"):
		node.queue_free()


func _on_exit_locked() -> void:
	_hud.show_toast("Cổng thoát đang khóa: hãy hạ Boss trước", 2.5)


func _on_exit_activated() -> void:
	exit_requested.emit()
