class_name GameFeel
extends Node
## Trung tâm "cảm giác chiến đấu": nghe sự kiện từ Player/Enemy/Boss rồi phát phản hồi (khựng khung hình, rung màn hình, âm thanh).
## Mọi con số lấy từ CombatTuning (Resources/combat_tuning.tres) nên chỉnh ở MỘT chỗ.
##  - Hitstop: tạm thời giảm Engine.time_scale về rất nhỏ trong vài chục mili-giây THỜI GIAN THỰC khi trúng đòn, giết Enemy, Player bị đánh.
##    Mọi bộ đếm của game (báo trước, hồi chiêu...) cùng chậm nên thời gian đánh luôn nhất quán.
##  - Né hoàn hảo: slow-mo ngắn khi lướt đúng lúc để đòn trúng vào khung bất tử.
## Main tạo node này, gán shaker, gọi bind_player() một lần, bind_enemy() cho mỗi Enemy mới, bind_boss() khi Boss xuất hiện.

var shaker: CameraShaker = null

var _player: Node = null
var _freeze_until_msec: int = 0
var _slowmo_until_msec: int = 0
var _slowmo_scale: float = 1.0
var _applied_scale: float = 1.0
var _last_warn_msec: int = 0
var _last_boom_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # đồng hồ thực phải chạy cả khi đang hitstop/pause


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # không bao giờ để game kẹt ở tốc độ chậm


func _process(_delta: float) -> void:
	_update_time_scale()


# ---------------------------------------------------------------- Hitstop và slow-mo
## Khựng khung hình duration giây (thời gian thực). Gọi nhiều lần thì lấy lần dài nhất.
func hitstop(duration: float) -> void:
	if not CombatTuning.current().hitstop_enabled or duration <= 0.0:
		return
	_freeze_until_msec = maxi(_freeze_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	_update_time_scale()


## Làm chậm game về time_scale trong duration giây thời gian thực.
func slowmo(time_scale: float, duration: float) -> void:
	_slowmo_scale = clampf(time_scale, 0.05, 1.0)
	_slowmo_until_msec = maxi(_slowmo_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	_update_time_scale()


func _update_time_scale() -> void:
	var now := Time.get_ticks_msec()
	var target := 1.0
	if now < _slowmo_until_msec:
		target = _slowmo_scale
	if now < _freeze_until_msec:
		target = minf(target, CombatTuning.current().hitstop_time_scale)
	if not is_equal_approx(target, _applied_scale):
		Engine.time_scale = target
		_applied_scale = target


func _shake(strength: float) -> void:
	if shaker != null:
		shaker.shake(strength, CombatTuning.current().shake_duration)


# ---------------------------------------------------------------- Gắn tín hiệu
func bind_player(player: Node) -> void:
	_player = player
	_connect(player, "damaged", _on_player_damaged)
	_connect(player, "dash_started", _on_player_dash)
	_connect(player, "spell_cast", _on_spell_cast)
	_connect(player, "perfect_dodge", _on_perfect_dodge)
	_connect(player, "ultimate_impact", _on_ultimate_impact)
	_connect(player, "ultimate_ready", _on_ultimate_ready)
	_connect(player, "rush_started", _on_rush_started)
	_connect(player, "shockwave_cast", _on_shockwave_cast)


func bind_enemy(enemy: Node) -> void:
	_connect(enemy, "damaged", _on_enemy_damaged)
	_connect(enemy, "died", _on_enemy_died)
	_connect(enemy, "state_changed", _on_enemy_state.bind(enemy))


func bind_boss(boss: Node) -> void:
	_connect(boss, "phase_changed", _on_boss_phase)
	_connect(boss, "impact", _on_boss_impact)
	_connect(boss, "telegraph_started", _on_boss_telegraph)
	_connect(boss, "died", _on_boss_died)


func _connect(node: Node, signal_name: StringName, callable: Callable) -> void:
	if node != null and node.has_signal(signal_name) and not node.is_connected(signal_name, callable):
		node.connect(signal_name, callable)


# ---------------------------------------------------------------- Phản hồi
func _on_enemy_damaged(amount: float, health_left: float) -> void:
	if health_left <= 0.0:
		return  # đòn kết liễu do _on_enemy_died xử lý
	var tuning := CombatTuning.current()
	var heavy := amount >= tuning.heavy_hit_damage
	hitstop(tuning.hitstop_heavy if heavy else tuning.hitstop_light)
	_shake(tuning.shake_heavy_hit if heavy else tuning.shake_hit)
	SfxPlayer.play_sfx(&"hit_heavy" if heavy else &"hit_light")


func _on_enemy_died(_enemy: Node = null) -> void:
	var tuning := CombatTuning.current()
	hitstop(tuning.hitstop_kill)
	_shake(tuning.shake_kill)
	SfxPlayer.play_sfx(&"enemy_die")


## Enemy thường bắt đầu báo trước: phát tiếng cảnh báo nhỏ (chỉ khi ở gần Player, giới hạn tần suất để không ồn).
func _on_enemy_state(new_state: int, enemy: Node) -> void:
	if new_state == Enemy.State.ATTACK and not (enemy is Boss) and is_instance_valid(enemy) and _player != null and is_instance_valid(_player) \
			and (enemy as Node2D).global_position.distance_to((_player as Node2D).global_position) < 500.0:
		SfxPlayer.play_sfx(&"enemy_atk", -6.0)
		return
	if new_state != Enemy.State.ATTACK_PREP or enemy is Boss or _player == null or not is_instance_valid(_player) or not is_instance_valid(enemy):
		return
	var now := Time.get_ticks_msec()
	if now - _last_warn_msec < 120:
		return
	if (enemy as Node2D).global_position.distance_to((_player as Node2D).global_position) > 650.0:
		return
	_last_warn_msec = now
	SfxPlayer.play_sfx(&"warn", -4.0)


func _on_player_damaged(_amount: float, _health_left: float) -> void:
	var tuning := CombatTuning.current()
	hitstop(tuning.hitstop_player_hurt)
	_shake(tuning.shake_player_hurt)
	SfxPlayer.play_sfx(&"player_hurt")


func _on_player_dash(_direction: Vector2) -> void:
	SfxPlayer.play_sfx(&"dash")


func _on_spell_cast(spell: SpellData) -> void:
	# Spell vùng nổ trầm hơn, spell đạn cao hơn một chút theo loại sát thương.
	var sid := String(spell.id)
	if sid.begins_with("fire"):
		SfxPlayer.play_sfx(&"fire", -2.0, 0.85 if spell.kind == SpellData.Kind.AREA else 1.0)
	elif sid.begins_with("frost"):
		SfxPlayer.play_sfx(&"ice")
	elif sid.begins_with("shadow"):
		SfxPlayer.play_sfx(&"shadow")
	elif sid.begins_with("shockwave"):
		SfxPlayer.play_sfx(&"shield")
	elif sid.begins_with("sk_"):  # kỹ năng thư viện: âm theo hệ sát thương
		match spell.damage_type:
			DamageInfo.Type.FIRE:
				SfxPlayer.play_sfx(&"fire", -2.0, 1.1)
			DamageInfo.Type.ICE:
				SfxPlayer.play_sfx(&"ice", 0.0, 1.1)
			DamageInfo.Type.DARK:
				SfxPlayer.play_sfx(&"shadow", 0.0, 1.15)
			_:
				SfxPlayer.play_sfx(&"cast", 0.0, 0.8 if spell.kind == SpellData.Kind.AREA else 1.15)
	else:
		var pitch := 0.75 if spell.kind == SpellData.Kind.AREA else 1.0 + 0.06 * float(spell.damage_type)
		SfxPlayer.play_sfx(&"cast", 0.0, pitch)


func _on_rush_started(upgraded: bool) -> void:
	SfxPlayer.play_sfx(&"roar" if upgraded else &"dash", -2.0, 1.3 if upgraded else 0.8)


## Cú đấm / chấn động của ô R chạm đất: rung màn hình và khựng khung hình theo độ mạnh.
func _on_shockwave_cast(_pos: Vector2, _radius: float) -> void:
	_shake(7.0)
	hitstop(CombatTuning.current().hitstop_heavy)
	SfxPlayer.play_sfx(&"boom", -3.0, 1.15)


func _on_ultimate_impact(_pos: Vector2, strength: float, upgraded: bool) -> void:
	_shake(strength)
	if upgraded:
		hitstop(CombatTuning.current().hitstop_boss_event)
		SfxPlayer.play_sfx(&"boom")
	else:
		hitstop(CombatTuning.current().hitstop_heavy)
		SfxPlayer.play_sfx(&"hit_heavy", 0.0, 0.8)


func _on_ultimate_ready() -> void:
	SfxPlayer.play_sfx(&"ultimate_ready")


func _on_perfect_dodge() -> void:
	var tuning := CombatTuning.current()
	slowmo(tuning.perfect_dodge_slowmo_scale, tuning.perfect_dodge_slowmo_time)
	SfxPlayer.play_sfx(&"perfect")


func _on_boss_phase(_phase: int) -> void:
	hitstop(CombatTuning.current().hitstop_boss_event)
	SfxPlayer.play_sfx(&"roar")


func _on_boss_impact(strength: float) -> void:
	var now := Time.get_ticks_msec()
	if strength >= 6.0 and now - _last_boom_msec > 250:
		_last_boom_msec = now
		SfxPlayer.play_sfx(&"boom", -3.0 + minf(strength, 14.0) * 0.2)


func _on_boss_telegraph(_pattern: int) -> void:
	SfxPlayer.play_sfx(&"warn_boss")


func _on_boss_died(_boss: Node = null) -> void:
	hitstop(CombatTuning.current().hitstop_boss_event)
	SfxPlayer.play_sfx(&"boom")
	SfxPlayer.play_sfx(&"roar", -2.0, 0.8)
