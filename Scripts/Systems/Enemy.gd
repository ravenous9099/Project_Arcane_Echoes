class_name Enemy
extends CharacterBody2D
## Enemy dùng bộ nhân vật "2D HD Character pack", có AI chiến đấu theo máy trạng thái (FSM):
##   IDLE -> DETECT -> CHASE -> ATTACK_PREP (báo trước) -> ATTACK -> RECOVERY -> CHASE ...
##   STUNNED (bị đánh trúng, ngắt báo trước) và DEAD.
## Ba kiểu (archetype): MELEE (áp sát, đánh gần), RANGED (giữ khoảng cách, bắn đạn), CASTER (giữ khoảng cách, phép).
## MỌI đòn đánh đều là một SpellData (attack_spell) được thi triển bằng SpellCaster dùng chung với Player,
## nên sát thương, đẩy lùi, i-frame của Player đều đi qua cùng hệ thống chiến đấu (DamageInfo -> take_damage).
## Mỗi scene Enemy chỉ cần: node gốc CharacterBody2D + script này + vài thông số trong Inspector.

## Phát ra đúng 1 lần khi Enemy chết. EnemySpawner sẽ lắng nghe để cập nhật bộ đếm.
signal died(enemy: Enemy)
## Phát ra mỗi lần nhận sát thương (dùng cho thanh máu, hiệu ứng... sau này).
signal damaged(amount: float, health_left: float)
## Phát ra mỗi khi đổi trạng thái (new_state là giá trị của enum State).
signal state_changed(new_state: int)

enum State { IDLE, DETECT, CHASE, ATTACK_PREP, ATTACK, RECOVERY, STUNNED, DEAD }
enum Archetype { MELEE, RANGED, CASTER }

@export_group("Nhân vật (hình ảnh)")
## Thư mục chứa các spritesheet của nhân vật, ví dụ:
## res://Assets/Characters/2D HD Character pack/Spritesheets/With shadow/7DeathKnight
@export_dir var character_folder: String = ""
## Kích thước 1 khung hình trong spritesheet (pixel).
@export var frame_size: int = 128
## Tốc độ phát animation (khung hình/giây).
@export var anim_fps: float = 12.0
## Tên file animation khi di chuyển: "Walk" hoặc "Run".
@export var move_animation: String = "Walk"
## Tên file animation khi tấn công. Knight/Paladin/DeathKnight: "Melee". Archer/Wizard: "QuickShot" hoặc "Attack1". Caster: "CastSpell".
@export var attack_animation: String = "Melee"
## Tỉ lệ hình. Player đang dùng 0.5 nên để cùng cỡ.
@export var sprite_scale: Vector2 = Vector2(0.5, 0.5)
## Dời hình lên/xuống nếu chân nhân vật không khớp với tâm va chạm.
@export var sprite_offset: Vector2 = Vector2.ZERO

@export_group("Va chạm")
## Bán kính thân (chặn đường đi), pixel.
@export var body_radius: float = 12.0

@export_group("Điểm số")
## Tên hiện trong bảng điểm.
@export var enemy_name: String = "Enemy"
## Số điểm Player nhận khi hạ gục Enemy này (ScoreTracker cộng).
@export var score_value: int = 10
## false: không rơi viên máu khi chết (Boss).
@export var drops_health: bool = true

@export_group("Chỉ số")
@export var max_health: float = 30.0
@export var move_speed: float = 60.0
## Enemy cận chiến dừng lại khi cách Player bao nhiêu pixel (tránh đẩy Player).
@export var stop_distance: float = 10.0

@export_group("Phát hiện")
## Thấy Player trong tầm này (pixel) thì bắt đầu để ý (IDLE -> DETECT).
@export var detection_range: float = 650.0
## Mất dấu khi Player ra xa hơn mức này (pixel). Nên lớn hơn detection_range để không chập chờn.
@export var lose_range: float = 950.0
## Thời gian "phản ứng" giữa lúc thấy Player và lúc bắt đầu đuổi theo (giây).
@export var detect_time: float = 0.35
## Bị đánh thì lập tức đuổi theo Player dù chưa phát hiện.
@export var aggro_on_damage: bool = true

@export_group("Chiến đấu")
@export var archetype: Archetype = Archetype.MELEE
## Đòn đánh (SpellData). Để trống = Enemy không có đòn, chỉ đuổi theo (và gây sát thương chạm nếu bật).
@export var attack_spell: SpellData
## Bắt đầu tấn công khi cách Player trong tầm này (pixel).
@export var attack_range: float = 48.0
## Chỉ RANGED/CASTER: lùi lại nếu Player đến gần hơn mức này (pixel). 0 = không lùi.
@export var keep_distance_min: float = 0.0
## Tốc độ lùi so với move_speed.
@export_range(0.1, 1.5, 0.05) var retreat_speed_multiplier: float = 0.8
## Thời gian tối thiểu giữa 2 lần ra đòn (giây), tính từ lúc đòn được tung ra.
@export var attack_cooldown: float = 1.5
## Thời gian báo trước (giây): Enemy đứng yên, có vùng cảnh báo trên đất. Player có thể né hoặc ngắt bằng cách đánh trúng.
@export var telegraph_time: float = 0.5
## Trong khoảng này (giây) cuối của giai đoạn báo trước, hướng/vị trí đánh bị KHÓA (đứng yên mới trúng).
@export var aim_lock_time: float = 0.25
## Thời gian đòn đánh đang diễn ra, không bị ngắt (giây).
@export var attack_active_time: float = 0.15
## Thời gian hồi sau đòn: Enemy đứng yên, là lúc nên phản công (giây).
@export var recovery_time: float = 0.5

@export_group("Bị đánh")
## Tốc độ đẩy lùi giảm dần mỗi giây (pixel/giây mỗi giây). Càng lớn càng dừng nhanh.
@export var knockback_decay: float = 900.0
## Kháng đẩy lùi: 0 = bị đẩy đủ, 1 = không bị đẩy (dùng cho enemy nặng/boss).
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0
## Thời gian choáng khi bị ngắt (giây).
@export var stun_duration: float = 0.35
## Sát thương nhỏ nhất của MỘT đòn đủ để làm choáng/ngắt báo trước. Enemy nặng đặt cao để "giáp cứng".
@export var stun_min_damage: float = 1.0
## Sau khi hết choáng, miễn nhiễm choáng trong khoảng này (giây) để không bị khóa choáng liên tục.
@export var stun_immunity_time: float = 0.6

@export_group("Gây sát thương khi chạm (tùy chọn)")
## 0 = tắt. Enemy mới dùng đòn đánh (attack_spell) nên mặc định tắt.
@export var contact_damage: float = 0.0
@export var contact_cooldown: float = 1.0
@export var contact_knockback: float = 100.0
@export var hitbox_radius: float = 18.0

@export_group("Hiển thị")
## Độ đậm tối thiểu của vùng cảnh báo (0..1); map sáng như tuyết cần giá trị cao hơn.
@export var telegraph_min_alpha: float = 0.3
@export var telegraph_color: Color = Color(1.0, 0.25, 0.2, 1.0)
## Màu khi hướng/vị trí đánh đã bị khóa.
@export var telegraph_lock_color: Color = Color(1.0, 0.85, 0.2, 1.0)
## Hiện tên trạng thái trên đầu Enemy để kiểm thử AI.
@export var debug_show_state: bool = false
## Chiều rộng thanh máu trên đầu (pixel).
@export var health_bar_width: float = 34.0
## Vị trí thanh máu so với tâm Enemy. Chỉnh nếu thanh đè lên đầu hoặc bay quá cao.
@export var health_bar_offset: Vector2 = Vector2(0.0, -34.0)
## false: chỉ hiện sau khi bị đánh. true: luôn hiện (dùng cho Boss/elite).
@export var health_bar_always_visible: bool = false

var health: float
var is_dead: bool = false
var target: Node2D = null

var _state: State = State.IDLE
var _state_time: float = 0.0
var _attack_cd: float = 0.0
var _stun_immunity: float = 0.0
var _stun_override: float = 0.0  # > 0: thời gian choáng bị ép (force_stun), thay cho stun_duration
var _contact_timer: float = 0.0
var _desired_velocity: Vector2 = Vector2.ZERO
var _knockback: Vector2 = Vector2.ZERO
var _attack_dir: Vector2 = Vector2.DOWN
var _attack_pos: Vector2 = Vector2.ZERO
var _row: int = 1  # hàng hướng nhìn trong spritesheet, 1 = nhìn xuống (Nam)
var _hit_playing: bool = false
# Nhớ animation đang phát để không phải tính lại tên animation mỗi frame (tiết kiệm khi có nhiều Enemy).
var _last_key: String = ""
var _last_row: int = -1

var _map: MapGenerator = null
var _los_timer: float = 0.0
var _los_clear: bool = true  # có nhìn thấy Player không (không bị tường chắn)

var _lock_flashed: bool = false  # đã nháy báo "hướng đã khóa" trong lần báo trước này chưa

var _anim_sprite: AnimatedSprite2D = null
var _body_shape: CollisionShape2D = null
var _hitbox: Area2D = null
var _caster: SpellCaster = null


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # top-down, không có "nền" để bám theo
	_apply_tuning()
	health = max_health
	add_to_group("enemies")
	_setup_collision()
	_setup_visuals()
	_setup_caster()
	_setup_health_bar()


## Áp các hệ số cân bằng chung (CombatTuning) lên chỉ số của Enemy. Boss ghi đè để dùng hệ số riêng.
func _apply_tuning() -> void:
	var tuning := CombatTuning.current()
	max_health *= tuning.enemy_health_multiplier
	move_speed *= tuning.enemy_speed_multiplier


## Màu "bình thường" của hình khi không bị nháy (Boss ở giai đoạn 2 có màu ám đỏ nên ghi đè).
func _rest_color() -> Color:
	return Color.WHITE


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_find_target_if_needed()
	_state_time += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_stun_immunity = maxf(_stun_immunity - delta, 0.0)
	_desired_velocity = Vector2.ZERO
	match _state:
		State.IDLE:
			_state_idle()
		State.DETECT:
			_state_detect()
		State.CHASE:
			_state_chase()
		State.ATTACK_PREP:
			_state_attack_prep()
		State.ATTACK:
			_state_attack()
		State.RECOVERY:
			_state_recovery()
		State.STUNNED:
			_state_stunned()
	_apply_motion(delta)
	_update_facing()
	_update_animation()
	if _state == State.ATTACK_PREP or debug_show_state:
		queue_redraw()
	_try_contact_attack(delta)


func get_state() -> State:
	return _state


func get_state_name() -> String:
	return State.keys()[_state]


# ---------------------------------------------------------------- Nhận sát thương
## Gọi từ đạn, kỹ năng, hoặc phím debug. info (tùy chọn) mang loại sát thương và lực đẩy lùi.
func take_damage(amount: float, info: DamageInfo = null) -> void:
	if is_dead:
		return
	if info != null and is_instance_valid(info.source) and info.source.is_in_group("player"):
		ComboSystem.register_hit()  # đánh trúng Enemy = +1 điểm combo
		RunStats.add_damage(minf(amount, maxf(health, 0.0)))  # tổng sát thương của lượt chơi (không tính phần dư khi hạ gục)
	health -= amount
	damaged.emit(amount, health)
	_notify_damage_source(info)
	CombatFx.spawn_damage_number(get_parent(), global_position + Vector2(0.0, -26.0), amount, info.type if info != null else DamageInfo.Type.PHYSICAL)
	if health <= 0.0:
		die()
		return
	if info != null:
		if info.force_knockback:
			apply_forced_knockback(info.knockback)
		else:
			apply_knockback(info.knockback)
	_flash()
	# Phản ứng với đòn đánh: bị đánh thì để ý Player ngay, và có thể bị ngắt báo trước.
	if aggro_on_damage and (_state == State.IDLE or _state == State.DETECT):
		_enter_state(State.CHASE)
	if _can_be_stunned(amount):
		_enter_state(State.STUNNED)


## Đẩy lùi Enemy (pixel/giây), giảm dần theo knockback_decay và knockback_resistance.
func apply_knockback(impulse: Vector2) -> void:
	_knockback = impulse * (1.0 - knockback_resistance) * CombatTuning.current().knockback_multiplier


## Đẩy lùi bỏ qua kháng đẩy (sóng xung kích Ultimate): kể cả Boss vẫn bị đẩy tối thiểu 45% lực.
func apply_forced_knockback(impulse: Vector2) -> void:
	_knockback = impulse * maxf(1.0 - knockback_resistance, 0.45) * CombatTuning.current().knockback_multiplier


## Báo cho nguồn sát thương (Player) biết đã đánh trúng / hạ gục để nạp mana. Nguồn nào không có hàm này thì bỏ qua.
func _notify_damage_source(info: DamageInfo) -> void:
	if info == null or info.source == null or not is_instance_valid(info.source) or info.source == self:
		return
	if info.source.has_method("on_dealt_damage"):
		info.source.call("on_dealt_damage", self, health <= 0.0)


## Ép choáng duration giây bất kể "giáp cứng" hay đang tung đòn (Shockwave Shield dùng cho Boss). Không áp dụng khi đã chết.
func force_stun(duration: float) -> void:
	if is_dead or _state == State.DEAD or duration <= 0.0:
		return
	_stun_override = duration
	_stun_immunity = 0.0
	_enter_state(State.STUNNED)


## Không thể choáng khi: đang tung đòn (ATTACK), đang choáng, còn miễn nhiễm, hoặc đòn quá nhẹ ("giáp cứng").
func _can_be_stunned(amount: float) -> bool:
	if _state == State.ATTACK or _state == State.STUNNED or _state == State.DEAD:
		return false
	return amount >= stun_min_damage and _stun_immunity <= 0.0


func die() -> void:
	if is_dead:  # chặn gọi trùng -> signal died chỉ phát 1 lần
		return
	is_dead = true
	_state = State.DEAD
	if _caster != null:
		_caster.reset()
	queue_redraw()  # xóa vùng cảnh báo còn trên đất
	# Rời nhóm "enemies" và tắt va chạm NGAY, để bộ đếm đúng dù animation chết còn đang chạy.
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	if _body_shape != null:
		_body_shape.set_deferred("disabled", true)
	if _hitbox != null:
		_hitbox.set_deferred("monitoring", false)
	died.emit(self)
	_try_drop_health()
	_try_drop_gold()
	_apply_kill_heal()
	if _play("die"):
		# Giải phóng khi animation xong; timer là phương án dự phòng.
		get_tree().create_timer(3.0).timeout.connect(queue_free)
	else:
		queue_free()


## Rơi vàng: Enemy thường có xác suất gold_drop_chance rơi gold_drop_min..max đồng; Boss ghi đè _roll_gold() (luôn rơi 100-120).
## Trả về Vector2i(tổng vàng, số đồng). tổng = 0 nghĩa là không rơi.
func _roll_gold() -> Vector2i:
	var tuning := CombatTuning.current()
	if randf() >= tuning.gold_drop_chance:
		return Vector2i.ZERO
	var total := randi_range(tuning.gold_drop_min, maxi(tuning.gold_drop_max, tuning.gold_drop_min))
	return Vector2i(total, total)


func _try_drop_gold() -> void:
	var roll := _roll_gold()
	if roll.x <= 0 or get_parent() == null:
		return
	GoldPickup.spawn_drop(get_parent(), global_position, roll.x, roll.y)


## Hồi máu cho Player khi hạ Enemy (buff combo rank S trở lên và relic Răng Ma Cà Rồng).
func _apply_kill_heal() -> void:
	var amount := PlayerStats.kill_heal_amount()
	if amount <= 0.0:
		return
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("heal") and not bool(player_node.get("is_dead")):
		player_node.call("heal", amount)
		CombatFx.spawn_text(get_parent(), player_node.global_position + Vector2(0.0, -62.0), "+%d" % int(amount), Color(0.5, 1.0, 0.6), 14)


## Có xác suất (CombatTuning.hp_drop_chance) rơi một viên máu tại chỗ Enemy chết. Boss ghi đè drops_health = false.
## Tạo viên bằng call_deferred vì die() có thể được gọi ngay giữa lúc Godot xử lý va chạm (đạn trúng), lúc đó không được thêm vật thể vật lý.
func _try_drop_health() -> void:
	if not drops_health:
		return
	var tuning := CombatTuning.current()
	if randf() >= tuning.hp_drop_chance + PlayerStats.hp_drop_bonus():
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var pickup := HealthPickup.new()
	pickup.heal_amount = tuning.hp_drop_heal
	pickup.lifetime = tuning.hp_drop_lifetime
	parent_node.add_child.call_deferred(pickup)
	pickup.set_deferred("global_position", global_position)


# ---------------------------------------------------------------- Dựng node
func _setup_collision() -> void:
	_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _body_shape == null:
		_body_shape = CollisionShape2D.new()
		_body_shape.name = "CollisionShape2D"
		add_child(_body_shape)
	var body_circle := CircleShape2D.new()
	body_circle.radius = body_radius
	_body_shape.shape = body_circle
	_body_shape.scale = Vector2.ONE

	if contact_damage <= 0.0:
		return  # không gây sát thương chạm thì không cần Hitbox
	_hitbox = get_node_or_null("Hitbox") as Area2D
	if _hitbox == null:
		_hitbox = Area2D.new()
		_hitbox.name = "Hitbox"
		add_child(_hitbox)
	_hitbox.scale = Vector2.ONE
	var hit_shape := _hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hit_shape == null:
		hit_shape = CollisionShape2D.new()
		hit_shape.name = "CollisionShape2D"
		_hitbox.add_child(hit_shape)
	var hit_circle := CircleShape2D.new()
	hit_circle.radius = hitbox_radius
	hit_shape.shape = hit_circle
	hit_shape.scale = Vector2.ONE


func _setup_health_bar() -> void:
	var health_bar := EnemyHealthBar.new()
	health_bar.name = "HealthBar"
	health_bar.setup(self, health_bar_width, health_bar_offset, health_bar_always_visible)
	add_child(health_bar)


func _setup_caster() -> void:
	_caster = SpellCaster.new()
	_caster.name = "SpellCaster"
	_caster.team = &"enemy"
	_caster.damage_multiplier = CombatTuning.current().enemy_damage_multiplier
	add_child(_caster)


func _setup_visuals() -> void:
	var frames := _build_frames()
	if frames == null:
		return  # giữ nguyên hình cũ (nếu có) và đã có cảnh báo trong Output
	# Bỏ hình Sprite2D cũ (ví dụ ảnh Kenney đã bị xóa).
	var legacy := get_node_or_null("Sprite2D")
	if legacy != null:
		legacy.queue_free()
	_anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _anim_sprite == null:
		_anim_sprite = AnimatedSprite2D.new()
		_anim_sprite.name = "AnimatedSprite2D"
		add_child(_anim_sprite)
	_anim_sprite.sprite_frames = frames
	_anim_sprite.scale = sprite_scale
	_anim_sprite.position = sprite_offset
	_anim_sprite.animation_finished.connect(_on_animation_finished)
	_play("idle")


## Cắt spritesheet thành animation "<loại>_<hàng>", ví dụ "move_3".
## Mỗi spritesheet có 8 hàng (8 hướng) x N cột (số khung hình), mỗi khung frame_size pixel.
func _build_frames() -> SpriteFrames:
	var sheets := {"idle": "Idle", "move": move_animation, "hit": "TakeDamage", "die": "Die", "attack": attack_animation}
	var loops := {"idle": true, "move": true, "hit": false, "die": false, "attack": false}
	return CharacterFrames.build(character_folder, sheets, loops, frame_size, anim_fps)


# ---------------------------------------------------------------- Máy trạng thái
func _enter_state(new_state: State) -> void:
	if _state == State.DEAD or is_dead:
		return
	_state = new_state
	_state_time = 0.0
	_last_key = ""  # buộc chọn lại animation idle/move một lần
	match new_state:
		State.ATTACK_PREP:
			# Mọi đòn đều có báo trước tối thiểu để luôn đọc được, dù số liệu chỉnh ở đâu.
			telegraph_time = maxf(telegraph_time, CombatTuning.current().min_telegraph_time)
			aim_lock_time = minf(aim_lock_time, telegraph_time)
			_lock_flashed = false
			_update_attack_aim()
			_start_attack_animation()
		State.ATTACK:
			_attack_cd = attack_cooldown
			_execute_attack()
		State.STUNNED:
			_caster.reset()
			_attack_cd = maxf(_attack_cd, attack_cooldown * 0.5)  # bị ngắt thì không đánh lại ngay lập tức
			_hit_playing = _play("hit")
			_fit_animation_to(stun_duration)
	queue_redraw()
	state_changed.emit(new_state)


func _state_idle() -> void:
	if _target_in_range(detection_range):
		_enter_state(State.DETECT)


func _state_detect() -> void:
	if not _target_in_range(lose_range):
		_enter_state(State.IDLE)
	elif _state_time >= detect_time:
		_enter_state(State.CHASE)


func _state_chase() -> void:
	if not _target_in_range(lose_range):
		_enter_state(State.IDLE)
		return
	_update_line_of_sight(get_physics_process_delta_time())
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.001 else Vector2.DOWN
	# Chỉ ra đòn khi nhìn thấy Player (không đánh/bắn vào tường).
	if attack_spell != null and _attack_cd <= 0.0 and dist <= attack_range and _los_clear:
		_enter_state(State.ATTACK_PREP)
		return
	if archetype == Archetype.MELEE:
		if dist > stop_distance:
			_desired_velocity = _chase_direction(dir) * move_speed
	elif dist > attack_range * 0.9 or not _los_clear:
		_desired_velocity = _chase_direction(dir) * move_speed  # còn xa hoặc bị tường chắn: tiến lại
	elif dist < keep_distance_min:
		_desired_velocity = -dir * move_speed * retreat_speed_multiplier  # quá gần: lùi ra


func _state_attack_prep() -> void:
	if target == null or not is_instance_valid(target):
		_enter_state(State.IDLE)
		return
	# Theo dõi Player cho tới khi hướng bị khóa ở phần cuối của giai đoạn báo trước.
	if _state_time < telegraph_time - aim_lock_time:
		_update_attack_aim()
	elif not _lock_flashed:
		_lock_flashed = true
		_flash_lock()  # nháy sáng báo "hướng đã khóa, sắp ra đòn"
	if _state_time >= telegraph_time:
		_enter_state(State.ATTACK)


func _state_attack() -> void:
	if _state_time >= attack_active_time:
		_enter_state(State.RECOVERY)


func _state_recovery() -> void:
	if _state_time >= recovery_time:
		_enter_state(State.CHASE if _target_in_range(lose_range) else State.IDLE)


func _state_stunned() -> void:
	if _state_time >= maxf(stun_duration, _stun_override):
		_stun_override = 0.0
		_stun_immunity = stun_immunity_time
		_enter_state(State.CHASE if _target_in_range(lose_range) else State.IDLE)


# ---------------------------------------------------------------- Tấn công
## Cập nhật hướng và điểm đánh theo Player. MELEE đánh vào điểm trước mặt (tầm với = cast_range của đòn),
## RANGED/CASTER đánh vào vị trí Player tại thời điểm cập nhật.
func _update_attack_aim() -> void:
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 1.0:
			_attack_dir = to_target.normalized()
		_attack_pos = target.global_position
	if archetype == Archetype.MELEE and attack_spell != null:
		var reach := attack_spell.cast_range if attack_spell.cast_range > 0.0 else 32.0
		_attack_pos = global_position + _attack_dir * reach


func _execute_attack() -> void:
	if attack_spell == null:
		return
	_caster.set_aim(_attack_dir, _attack_pos)
	_caster.cast(attack_spell)


## Animation tấn công trải đều trong thời gian báo trước + đòn đánh.
func _start_attack_animation() -> void:
	if _anim_sprite == null or not _play("attack"):
		return
	_hit_playing = false
	_fit_animation_to(telegraph_time + attack_active_time)


# ---------------------------------------------------------------- Di chuyển
func _apply_motion(delta: float) -> void:
	# Đang bị đẩy lùi: bị hất đi, không tự đi cho tới khi lực đẩy gần hết.
	if _knockback.length_squared() > 1.0:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	else:
		velocity = _desired_velocity
	move_and_slide()


## Hướng đi tới Player: đi thẳng khi nhìn thấy nhau, bị tường chắn thì theo bản đồ hướng đi của MapGenerator để vòng qua tường.
func _chase_direction(direct: Vector2) -> Vector2:
	if _los_clear:
		return direct
	if _map == null or not is_instance_valid(_map):
		_map = get_tree().get_first_node_in_group("map_generator") as MapGenerator
	if _map == null:
		return direct
	var nav := _map.get_flow_direction(global_position)
	return nav if nav != Vector2.ZERO else direct


## Kiểm tra tầm nhìn tới Player bằng tia vật lý (chỉ tường tĩnh mới chắn), mỗi ~0.25 giây một lần cho nhẹ.
func _update_line_of_sight(delta: float) -> void:
	_los_timer -= delta
	if _los_timer > 0.0:
		return
	_los_timer = 0.2 + randf() * 0.1
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	_los_clear = hit.is_empty() or not (hit["collider"] is StaticBody2D)


func _find_target_if_needed() -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D


## Player còn tồn tại, còn sống và nằm trong tầm max_dist.
func _target_in_range(max_dist: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if bool(target.get("is_dead")):
		return false
	return global_position.distance_to(target.global_position) <= max_dist


func _try_contact_attack(delta: float) -> void:
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	if contact_damage <= 0.0 or _contact_timer > 0.0 or _hitbox == null:
		return
	for body in _hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			var push := (body.global_position - global_position).normalized() * contact_knockback
			DamageInfo.create(contact_damage, DamageInfo.Type.PHYSICAL, self, push).apply_to(body)
			_contact_timer = contact_cooldown
			return


# ---------------------------------------------------------------- Vẽ cảnh báo
## Vùng cảnh báo vẽ DƯỚI hình Enemy: vòng tròn (đòn vùng) hoặc làn đạn (đòn bắn).
func _draw() -> void:
	if debug_show_state and _state != State.DEAD:
		draw_string(ThemeDB.fallback_font, Vector2(-30.0, -60.0), get_state_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if _state == State.DETECT:
		draw_string(ThemeDB.fallback_font, Vector2(-4.0, -46.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.2))
		return
	if _state != State.ATTACK_PREP or attack_spell == null:
		return
	var progress := clampf(_state_time / maxf(telegraph_time, 0.01), 0.0, 1.0)
	var locked := _state_time >= telegraph_time - aim_lock_time
	var color := telegraph_lock_color if locked else telegraph_color
	color.a = 0.35 + 0.4 * progress
	match attack_spell.kind:
		SpellData.Kind.AREA:
			var center := to_local(_attack_pos)
			draw_arc(center, attack_spell.area_radius, 0.0, TAU, 40, color, 2.0)
			draw_circle(center, attack_spell.area_radius * progress, Color(color, color.a * 0.5))
		SpellData.Kind.PROJECTILE:
			var length := minf(attack_spell.projectile_speed * attack_spell.projectile_lifetime, 420.0)
			draw_line(_attack_dir * 14.0, _attack_dir * length, color, maxf(attack_spell.projectile_radius * 2.0, 3.0))
		SpellData.Kind.SKILL:
			# Kỹ năng nhiều bước (dùng chung với Player): báo trước bằng một vạch hướng bắn, tầm = bước đạn xa nhất (hoặc 160 px).
			var reach := 160.0
			for step in attack_spell.steps:
				if step != null and step.type == SkillStep.Type.PROJECTILE:
					reach = maxf(reach, minf(step.max_range, 420.0))
			draw_line(_attack_dir * 14.0, _attack_dir * reach, color, 4.0)


# ---------------------------------------------------------------- Hình ảnh
## Enemy quay mặt về phía Player; khi đang tấn công thì quay theo hướng đánh đã tính.
func _update_facing() -> void:
	if _state == State.ATTACK_PREP or _state == State.ATTACK:
		_row = CharacterFrames.direction_row(_attack_dir)
		return
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target.length() > 1.0:
		_row = CharacterFrames.direction_row(to_target)


func _update_animation() -> void:
	if _hit_playing or _anim_sprite == null or _state == State.ATTACK_PREP or _state == State.ATTACK:
		return
	var key := "move" if velocity.length() > 1.0 else "idle"
	if key == _last_key and _row == _last_row:
		return  # không có gì đổi, khỏi gọi lại
	_last_key = key
	_last_row = _row
	_play(key)


## Phát animation theo loại ("idle", "move", "hit", "die", "attack"). Trả về false nếu không có animation đó.
func _play(key: String) -> bool:
	if _anim_sprite == null:
		return false
	var frames := _anim_sprite.sprite_frames
	var anim_name := "%s_%d" % [key, _row]
	if not frames.has_animation(anim_name):
		anim_name = "%s_0" % key
		if not frames.has_animation(anim_name):
			return false
	# "hit", "die", "attack" luôn phát lại từ đầu; idle/move chỉ đổi khi khác animation hiện tại.
	if key == "hit" or key == "die" or key == "attack" or _anim_sprite.animation != anim_name or not _anim_sprite.is_playing():
		# Chỉ đổi HƯỚNG của idle/move thì giữ nguyên khung hình đang chạy, tránh giật về khung đầu.
		var keep_frame := (key == "idle" or key == "move") and _anim_sprite.is_playing() \
				and String(_anim_sprite.animation).begins_with(key + "_")
		var old_frame := _anim_sprite.frame
		var old_progress := _anim_sprite.frame_progress
		_anim_sprite.speed_scale = 1.0
		_anim_sprite.play(anim_name)
		if keep_frame and old_frame < frames.get_frame_count(anim_name):
			_anim_sprite.set_frame_and_progress(old_frame, old_progress)
	return true


## Tăng tốc animation đang phát để vừa trong duration giây (chỉ tăng, tối đa 4 lần).
func _fit_animation_to(duration: float) -> void:
	if _anim_sprite == null or duration <= 0.0:
		return
	var frames := _anim_sprite.sprite_frames
	var anim_name := _anim_sprite.animation
	if not frames.has_animation(anim_name):
		return
	var anim_length := frames.get_frame_count(anim_name) / maxf(frames.get_animation_speed(anim_name), 0.01)
	if anim_length > duration:
		_anim_sprite.speed_scale = minf(anim_length / duration, 4.0)


func _on_animation_finished() -> void:
	if is_dead:
		queue_free()
	else:
		_hit_playing = false
		_last_key = ""


func _flash() -> void:
	if _anim_sprite == null:
		return
	_anim_sprite.modulate = Color(1.0, 0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(_anim_sprite, "modulate", _rest_color(), 0.15)


## Nháy vàng sáng ngắn khi hướng đánh bị khóa: Player biết từ giờ đứng yên sẽ trúng, phải di chuyển/lướt.
func _flash_lock() -> void:
	if _anim_sprite == null:
		return
	_anim_sprite.modulate = Color(1.6, 1.45, 0.6)
	var tw := create_tween()
	tw.tween_property(_anim_sprite, "modulate", _rest_color(), 0.14)
