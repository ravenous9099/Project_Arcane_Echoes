extends CharacterBody2D
## Nhân vật chính: Pháp sư (6Mage). Di chuyển 8 hướng, thi triển spell, có máu, nhận sát thương và có thể chết / hồi sinh.
## Hình ảnh được dựng bằng code từ spritesheet (xem CharacterFrames.gd).
## Việc thi triển spell do SpellCaster (con của Player, tạo bằng code) đảm nhiệm; danh sách spell và cooldown nằm ở SpellSystem.

## Phát ra khi nhận sát thương (dùng cho HUD, hiệu ứng...).
signal damaged(amount: float, health_left: float)
## Phát ra đúng 1 lần khi Player chết. Main nghe signal này để kết thúc lượt chơi.
signal died
## Phát ra khi bắt đầu / kết thúc lướt (HUD, âm thanh, hiệu ứng nghe signal này).
signal dash_started(direction: Vector2)
signal dash_ended
## Phát ra mỗi khi một Spell thật sự được bắn (GameFeel dùng cho âm thanh).
signal spell_cast(spell: SpellData)
## Phát ra khi một đòn trúng vào khung bất tử của dash ("né hoàn hảo"): GameFeel làm slow-mo và phát âm thanh.
signal perfect_dodge
## Bắt đầu lao đấm (ô R). upgraded = true khi là bản Ultimate (đã tiêu 100 mana).
signal rush_started(upgraded: bool)
## Cú đấm cuối / chấn động của ô R chạm đất tại position; strength dùng cho rung màn hình và hitstop (GameFeel).
signal ultimate_impact(position: Vector2, strength: float, upgraded: bool)
## Mana vừa đầy: ô R chuyển thành Ultimate nâng cấp và được reset hồi chiêu.
signal ultimate_ready
## Dùng Shockwave Shield: GameFeel rung màn hình / âm thanh.
signal shockwave_cast(position: Vector2, radius: float)

## Các phím spell tương ứng với ô trang bị 0..3 trong SpellSystem (Input Map: spell_1 ... spell_4).
const SPELL_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]

@export var speed: float = 150.0

@export_group("Máu")
@export var max_health: float = 100.0
## Sau mỗi lần trúng đòn, Player miễn sát thương trong khoảng này (giây) để không bị "đấm" liên tục.
@export var invulnerable_time: float = 0.5
## Tốc độ đẩy lùi giảm dần mỗi giây (pixel/giây mỗi giây). Càng lớn càng dừng nhanh.
@export var knockback_decay: float = 900.0
## Giới hạn tốc độ bị đẩy lùi (pixel/giây), tránh bị hất văng xuyên map.
@export var max_knockback_speed: float = 500.0

@export_group("Va chạm")
## Bán kính thân (chặn đường đi), pixel. Trước đây là hình chữ nhật bị phóng 16 lần (~45px), nay dùng hình tròn.
@export var body_radius: float = 10.0
## Dời hình va chạm so với tâm node (pixel), chỉnh nếu chân nhân vật không khớp.
@export var body_offset: Vector2 = Vector2.ZERO

@export_group("Dash (lướt)")
## Tốc độ lướt ban đầu (pixel/giây). Quãng đường ~ dash_speed * dash_duration * (1 + dash_end_speed_ratio) / 2.
@export var dash_speed: float = 560.0
## Thời gian lướt (giây).
@export var dash_duration: float = 0.2
## Tốc độ cuối lần lướt so với tốc độ đầu (1 = lướt đều, nhỏ hơn = giảm tốc mượt khi kết thúc).
@export_range(0.0, 1.0, 0.05) var dash_end_speed_ratio: float = 0.5
## Thời gian hồi để có lại MỘT lượt lướt (giây), tính từ lúc bắt đầu lướt.
@export var dash_cooldown: float = 0.9
## Số lượt lướt tối đa dự trữ. 1 = chỉ lướt lại sau khi hồi xong; 2+ cho phép lướt liên tiếp.
@export var dash_max_charges: int = 1
## Bấm dash hơi sớm (trong lúc đang hồi / đang cast) vẫn được nhận nếu trong khoảng này (giây).
@export var dash_buffer_time: float = 0.1
## Bất tử trong lúc lướt (né đòn).
@export var dash_invulnerable: bool = true
## Thời gian bất tử tính từ lúc bắt đầu lướt (giây), tối đa bằng dash_duration là hợp lý.
@export var dash_iframe_duration: float = 0.2
## Cho phép lướt để HỦY giai đoạn hồi sau khi bắn spell (spell đã bắn rồi nên không mất gì).
@export var dash_can_cancel_recovery: bool = true
## Cho phép lướt để HỦY giai đoạn chuẩn bị spell (spell bị hủy, KHÔNG mất cooldown vì chưa bắn).
@export var dash_can_cancel_windup: bool = false
@export_subgroup("Vệt mờ")
@export var dash_trail_color: Color = Color(0.55, 0.8, 1.0, 0.55)
## Khoảng thời gian giữa 2 bóng mờ (giây).
@export var dash_trail_interval: float = 0.03
## Thời gian một bóng mờ tan biến (giây).
@export var dash_trail_fade: float = 0.25

@export_group("Thi triển spell")
## Tốc độ di chuyển khi đang thi triển spell (1 = không chậm đi).
@export_range(0.0, 1.0, 0.05) var cast_move_speed_multiplier: float = 0.6
## Animation thi triển được tăng tốc để vừa thời gian cast + hồi, nhưng không nhanh hơn mức này.
@export var max_cast_anim_speed: float = 4.0

@export_group("Lao đấm R (Ultimate)")
## Màu bóng mờ để lại khi lao đấm.
@export var rush_trail_color: Color = Color(1.0, 0.45, 0.15, 0.6)
## Bất tử trong lúc lao đấm (cộng thêm một chút sau khi kết thúc, giây).
@export var rush_iframe_extra: float = 0.1
## Khựng sau khi lao đấm xong (giây): bản thường / bản Ultimate.
@export var rush_end_lag: float = 0.1
@export var ultimate_end_lag: float = 0.25

@export_group("Nhân vật (hình ảnh)")
## Thư mục chứa spritesheet của nhân vật. Đổi sang thư mục khác để đổi nhân vật.
@export_dir var character_folder: String = "res://Assets/Characters/2D HD Character pack/Spritesheets/With shadow/6Mage"
## Kích thước 1 khung hình trong spritesheet (pixel).
@export var frame_size: int = 128
## Tốc độ phát animation (khung hình/giây).
@export var anim_fps: float = 12.0
## Animation khi di chuyển: "Walk" hoặc "Run".
@export var move_animation: String = "Walk"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: float
var is_dead: bool = false

# Hướng mà nhân vật đang nhìn khi đứng yên
var last_direction := Vector2.DOWN

# true = đã dựng được animation mới từ thư mục nhân vật; false = dùng animation cũ trong Player.tscn
var _using_character_frames: bool = false
var _invulnerable_timer: float = 0.0
var _input_direction := Vector2.ZERO
var _knockback := Vector2.ZERO
var _caster: SpellCaster = null
var _is_casting: bool = false
var _spell_buffer: Array[float] = [0.0, 0.0, 0.0, 0.0]  # thời gian còn lại của lần bấm spell đã được nhớ, theo ô
var _dash_lag_timer: float = 0.0  # khựng sau khi lướt xong (cái giá của dash)
var _perfect_cd: float = 0.0
## Thanh mana của Ultimate (tạo bằng code, chỉ hiện trên HUD sau khi nhặt Ultimate).
var mana: ManaPool = null

# --- Trạng thái bất lợi (Boss 3 / CamoArcher): choáng và trói chân
## Sau khi hết choáng, Player miễn nhiễm choáng/trói thêm chừng này giây (chống bị khóa liên tục).
@export var status_immunity_time: float = 0.8
var _stun_timer: float = 0.0
var _root_timer: float = 0.0
var _status_immunity: float = 0.0
## Còn bao lâu trường bảo hộ (Shockwave Shield) miễn nhiễm mọi sát thương.
var _shield_timer: float = 0.0

# --- Trạng thái lao đấm (ô R)
var _is_rushing: bool = false
var _rush_spell: SpellData = null
var _rush_upgraded: bool = false
var _rush_dir := Vector2.RIGHT
var _rush_speed: float = 0.0
var _rush_duration: float = 0.1
var _rush_elapsed: float = 0.0
var _rush_jabs_done: int = 0
var _rush_trail_timer: float = 0.0
var _rush_iframe_timer: float = 0.0  # bất tử riêng của lao đấm (không tính là "né hoàn hảo")
var _mouse_bound_slots: Array[bool] = []  # ô spell nào gán bằng nút chuột

# --- Trạng thái dash
var _is_dashing: bool = false
var _dash_direction := Vector2.DOWN
var _dash_elapsed: float = 0.0
var _dash_charges: int = 0
var _dash_recharge_timer: float = 0.0  # > 0: đang hồi một lượt lướt
var _dash_buffer_timer: float = 0.0
var _dash_iframe_timer: float = 0.0
var _dash_trail_timer: float = 0.0
## Kỹ năng DASH (ví dụ Inferno Dash Puff) đi kèm cú lướt hiện tại: null = lướt thường (chưa có kỹ năng hoặc đang hồi chiêu).
var _dash_skill: SpellData = null
var _dash_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Game nhìn từ trên xuống: FLOATING để không coi Enemy/Boss là "nền di chuyển" (nếu không Player bị cuốn theo vận tốc của họ).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	health = max_health
	_dash_charges = maxi(dash_max_charges, 1)
	_setup_collision()
	_setup_animations()
	_setup_caster()
	_setup_mana()
	_cache_mouse_bound_slots()


func _physics_process(delta: float) -> void:
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
	_dash_iframe_timer = maxf(_dash_iframe_timer - delta, 0.0)
	_rush_iframe_timer = maxf(_rush_iframe_timer - delta, 0.0)
	_dash_lag_timer = maxf(_dash_lag_timer - delta, 0.0)
	_perfect_cd = maxf(_perfect_cd - delta, 0.0)
	_status_immunity = maxf(_status_immunity - delta, 0.0)
	_shield_timer = maxf(_shield_timer - delta, 0.0)
	if is_dead:
		return
	_update_status(delta)
	_input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _stun_timer > 0.0:
		# Choáng: không nhận phím, chỉ trôi theo lực đẩy lùi.
		_update_dash_input(delta)
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
		move_and_slide()
		return
	if _root_timer > 0.0:
		_input_direction = Vector2.ZERO  # trói chân: không đi được (vẫn dùng spell, vẫn xoay theo chuột)
	_update_dash_input(delta)
	if _is_rushing:
		_process_rush(delta)  # lao đấm: bỏ qua phím di chuyển và phím spell tới khi xong
	elif _is_dashing:
		# Đang lướt: bỏ qua phím di chuyển và phím spell cho tới khi lướt xong.
		_process_dash(delta)
	else:
		get_movement(delta)
		_handle_spell_input()
		update_animation()
	move_and_slide()


func get_movement(delta: float) -> void:
	var move_speed := speed * PlayerStats.move_speed_multiplier() * (cast_move_speed_multiplier if _is_casting else 1.0) * (0.5 if _dash_lag_timer > 0.0 else 1.0)
	velocity = _input_direction * move_speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)

	# Chỉ cập nhật hướng nhìn khi nhân vật thực sự di chuyển (và không đang ngắm bắn: lúc đó nhìn theo chuột)
	if _input_direction != Vector2.ZERO and not _is_casting:
		last_direction = _input_direction.normalized()


# ---------------------------------------------------------------- Dash
## Quy tắc dash:
##  - Hướng lướt = hướng phím di chuyển đang giữ (làm tròn về 8 hướng). Không giữ phím nào thì lướt theo hướng đang nhìn.
##  - Mỗi lần bấm chỉ lướt 1 lần (giữ phím KHÔNG lặp lại). Bấm sớm trong dash_buffer_time sẽ được nhớ lại.
##  - Đang lướt thì không di chuyển bằng phím và không thi triển spell. Va tường / Enemy thì bị chặn như bình thường.
##  - Đang chuẩn bị spell: chặn dash (trừ khi dash_can_cancel_windup). Đang hồi sau spell: cho dash (dash_can_cancel_recovery).
func _update_dash_input(delta: float) -> void:
	# Hồi lượt lướt
	var max_charges := maxi(dash_max_charges, 1)
	_dash_charges = mini(_dash_charges, max_charges)
	if _dash_charges >= max_charges:
		_dash_recharge_timer = 0.0
	else:
		_dash_recharge_timer -= delta
		if _dash_recharge_timer <= 0.0:
			_dash_charges += 1
			_dash_recharge_timer = dash_cooldown if _dash_charges < max_charges else 0.0
	# Nhận phím (just_pressed: giữ phím không bắn lặp lại)
	_dash_buffer_timer = maxf(_dash_buffer_timer - delta, 0.0)
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time
	if _dash_buffer_timer > 0.0 and _can_dash():
		_start_dash()


func _can_dash() -> bool:
	if _is_dashing or _is_rushing or is_dead or _dash_charges <= 0 or _stun_timer > 0.0 or _root_timer > 0.0:
		return false
	match _caster.state:
		SpellCaster.State.WINDUP:
			return dash_can_cancel_windup
		SpellCaster.State.RECOVERY:
			return dash_can_cancel_recovery
	return true


func _start_dash() -> void:
	var raw_direction := _input_direction if _input_direction != Vector2.ZERO else last_direction
	_dash_direction = _snap_to_8_directions(raw_direction)
	_dash_buffer_timer = 0.0
	# Hủy thi triển đang dở (nếu được phép ở _can_dash)
	if _caster.is_busy():
		_caster.reset()
	_is_casting = false
	_is_dashing = true
	_dash_elapsed = 0.0
	_dash_trail_timer = 0.0
	_knockback = Vector2.ZERO
	last_direction = _dash_direction
	# Tiêu một lượt; nếu chưa có đồng hồ hồi thì bắt đầu đếm
	_dash_charges -= 1
	if _dash_recharge_timer <= 0.0:
		_dash_recharge_timer = dash_cooldown
	_dash_start_pos = global_position
	_dash_skill = _find_ready_dash_skill()
	if dash_invulnerable:
		_dash_iframe_timer = maxf(_dash_iframe_timer, dash_iframe_duration)
	if _using_character_frames:
		_play_key("dash", true)
		var anim_name := animated_sprite.animation
		var frames := animated_sprite.sprite_frames
		if frames.has_animation(anim_name) and String(anim_name).begins_with("dash_") and dash_duration > 0.0:
			var anim_length := frames.get_frame_count(anim_name) / maxf(frames.get_animation_speed(anim_name), 0.01)
			animated_sprite.speed_scale = maxf(anim_length / dash_duration, 1.0)
		else:
			animated_sprite.speed_scale = 1.0
	else:
		animated_sprite.speed_scale = 1.0
	dash_started.emit(_dash_direction)
	_spawn_trail_ghost()


func _process_dash(delta: float) -> void:
	_dash_elapsed += delta
	var t := clampf(_dash_elapsed / maxf(dash_duration, 0.01), 0.0, 1.0)
	velocity = _dash_direction * dash_speed * lerpf(1.0, dash_end_speed_ratio, t)
	_dash_trail_timer -= delta
	if _dash_trail_timer <= 0.0:
		_dash_trail_timer = dash_trail_interval
		_spawn_trail_ghost()
	if _dash_elapsed >= dash_duration:
		_end_dash()


func _end_dash() -> void:
	if not _is_dashing:
		return
	_is_dashing = false
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	_dash_lag_timer = CombatTuning.current().dash_end_lag  # lướt xong bị khựng một chút: đừng lướt bừa
	_trigger_dash_skill()
	dash_ended.emit()


## Kỹ năng DASH đang trang bị ở ô thường và đã hồi xong (null nếu không có / đang hồi: lướt thường, không kèm hiệu ứng).
func _find_ready_dash_skill() -> SpellData:
	for slot in SpellSystem.REGULAR_SLOT_COUNT:
		var spell := SpellSystem.get_equipped(slot)
		if spell != null and spell.kind == SpellData.Kind.DASH and SpellSystem.is_ready(spell):
			return spell
	return null


## Cuối cú lướt: chạy các bước của kỹ năng DASH tại điểm đến và dọc đường lướt, rồi bắt đầu hồi chiêu.
func _trigger_dash_skill() -> void:
	var spell := _dash_skill
	_dash_skill = null
	if spell == null or get_parent() == null:
		return
	var ctx := SkillRunner.make_ctx(spell, &"player", self, PlayerStats.damage_multiplier(), global_position, _dash_direction, global_position + _dash_direction * 32.0, get_parent())
	ctx.path_from = _dash_start_pos
	ctx.path_to = global_position
	SkillRunner.start(ctx, spell.steps)
	SpellSystem.start_cooldown(spell)
	spell_cast.emit(spell)


## Dừng dash ngay không phát signal (chết, hồi sinh).
func _cancel_dash() -> void:
	_is_dashing = false
	_dash_skill = null
	_dash_iframe_timer = 0.0
	animated_sprite.speed_scale = 1.0


## Làm tròn một vector về 1 trong 8 hướng.
func _snap_to_8_directions(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.DOWN
	return Vector2.from_angle(snappedf(direction.angle(), PI / 4.0))


## Bóng mờ để lại phía sau khi lướt: một Sprite2D chụp khung hình hiện tại rồi mờ dần và tự xóa.
func _spawn_trail_ghost(tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var frames := animated_sprite.sprite_frames
	var parent_node := get_parent()
	if frames == null or parent_node == null or not frames.has_animation(animated_sprite.animation):
		return
	var tex := frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.centered = animated_sprite.centered
	ghost.offset = animated_sprite.offset
	ghost.flip_h = animated_sprite.flip_h
	ghost.modulate = tint if tint.a > 0.0 else dash_trail_color
	parent_node.add_child(ghost)
	ghost.global_position = animated_sprite.global_position
	ghost.global_scale = animated_sprite.global_scale
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, dash_trail_fade)
	tw.tween_callback(ghost.queue_free)


## Dành cho HUD: đang lướt không, số lượt còn lại, và thời gian tới khi có thêm một lượt.
func is_dashing() -> bool:
	return _is_dashing


func get_dash_charges() -> int:
	return _dash_charges


func get_dash_cooldown_remaining() -> float:
	return maxf(_dash_recharge_timer, 0.0) if _dash_charges < maxi(dash_max_charges, 1) else 0.0


## 0 = sẵn sàng, 1 = vừa lướt xong (cho lớp phủ cooldown của HUD).
func get_dash_cooldown_ratio() -> float:
	if dash_cooldown <= 0.0:
		return 0.0
	return clampf(get_dash_cooldown_remaining() / dash_cooldown, 0.0, 1.0)


# ---------------------------------------------------------------- Spell
func _setup_caster() -> void:
	_caster = SpellCaster.new()
	_caster.name = "SpellCaster"
	_caster.team = &"player"
	add_child(_caster)
	_caster.cast_started.connect(_on_cast_started)
	_caster.spell_fired.connect(_on_spell_fired)
	_caster.cast_finished.connect(_on_cast_ended)
	_caster.cast_interrupted.connect(_on_cast_interrupted)


## Giữ phím spell_N để thi triển Spell đang trang bị ở ô N (bắn liên tục khi hết cooldown).
func _handle_spell_input() -> void:
	var aim := _get_aim_direction()
	_caster.set_aim(aim, get_global_mouse_position())
	var tuning := CombatTuning.current()
	var delta := get_physics_process_delta_time()
	# Chuột đang trỏ vào nút giao diện (tạm dừng, chữ debug, chơi lại...) thì bấm chuột là bấm nút, không bắn spell.
	var over_gui := get_viewport().gui_get_hovered_control() != null
	# Đệm đầu vào: bấm hơi sớm khi đang hồi/đang cast/đang khựng sau lướt thì vẫn được nhớ và bắn ngay khi được (không "nuốt" phím).
	for slot in SPELL_ACTIONS.size():
		_spell_buffer[slot] = maxf(_spell_buffer[slot] - delta, 0.0)
		if Input.is_action_just_pressed(SPELL_ACTIONS[slot]) and not (over_gui and _mouse_bound_slots[slot]):
			_spell_buffer[slot] = tuning.spell_buffer_time
	if _caster.is_busy() or _dash_lag_timer > 0.0:
		return
	_caster.damage_multiplier = PlayerStats.damage_multiplier()
	for slot in SPELL_ACTIONS.size():
		if over_gui and _mouse_bound_slots[slot]:
			continue
		if not (Input.is_action_pressed(SPELL_ACTIONS[slot]) or _spell_buffer[slot] > 0.0):
			continue
		var spell := SpellSystem.get_equipped(slot)
		if spell == null or not SpellSystem.is_ready(spell):
			continue
		if spell.kind == SpellData.Kind.SHIELD:
			if _cast_shockwave_shield(spell):
				_spell_buffer[slot] = 0.0
				return
			continue
		if spell.kind == SpellData.Kind.DASH:
			if _can_dash():
				_start_dash()  # _start_dash tự gắn kỹ năng DASH đã hồi xong vào cú lướt
				_spell_buffer[slot] = 0.0
				return
			continue
		if spell.kind == SpellData.Kind.RUSH:
			if _start_rush(spell):
				_spell_buffer[slot] = 0.0
				return
			continue
		if _caster.cast(spell):
			_spell_buffer[slot] = 0.0
			return  # mỗi lần chỉ bắt đầu một spell


# ---------------------------------------------------------------- Shockwave Shield
## Dùng ngay tại chỗ (không cần ngắm): sóng chấn động bán kính shield_radius.
##  - Enemy thường trong vùng: bị đẩy lùi + shield_damage sát thương. Boss: bị choáng shield_boss_stun giây (và chịu sát thương).
##  - Player hồi shield_heal máu, nhận trường bảo hộ miễn nhiễm sát thương shield_duration giây.
## Bấm được cả khi đang bị trói chân; bị choáng thì không (đã chặn từ _physics_process). Hủy lướt đang chạy.
func _cast_shockwave_shield(spell: SpellData) -> bool:
	if _is_rushing or _is_dashing or _caster.is_busy():
		return false
	SpellSystem.start_cooldown(spell)
	var origin := global_position
	var radius := spell.shield_radius
	var radius_sq := radius * radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
			continue
		var offset := enemy.global_position - origin
		if offset.length_squared() > radius_sq:
			continue
		var dir := offset.normalized() if offset.length_squared() > 1.0 else Vector2.RIGHT
		var info := DamageInfo.create(spell.shield_damage * PlayerStats.damage_multiplier(), DamageInfo.Type.ARCANE, self, dir * spell.shield_knockback, spell)
		info.force_knockback = true
		info.apply_to(enemy)
		if enemy.has_method("force_stun") and enemy is Boss:
			enemy.call("force_stun", spell.shield_boss_stun)
	heal(spell.shield_heal)
	CombatFx.spawn_text(get_parent(), origin + Vector2(0.0, -56.0), "+%d HP" % int(spell.shield_heal), Color(0.5, 1.0, 0.65), 16)
	_shield_timer = maxf(_shield_timer, spell.shield_duration)
	var fx := ShockwaveFx.new()
	fx.radius = radius
	fx.color = spell.color
	get_parent().add_child(fx)
	fx.global_position = origin
	for old in get_children():
		if old is ShieldBubble:
			old.queue_free()
	var bubble := ShieldBubble.new()
	bubble.duration = spell.shield_duration
	bubble.color = spell.color
	add_child(bubble)
	shockwave_cast.emit(origin, radius)
	spell_cast.emit(spell)
	return true


func is_shielded() -> bool:
	return _shield_timer > 0.0


# ---------------------------------------------------------------- Mana và lao đấm (ô R)
func _setup_mana() -> void:
	mana = ManaPool.new()
	mana.name = "ManaPool"
	add_child(mana)
	mana.became_full.connect(_on_mana_full)
	SpellSystem.ultimate_acquired.connect(_on_ultimate_acquired)
	if SpellSystem.has_ultimate():
		mana.unlock()


func _on_ultimate_acquired(_spell: SpellData) -> void:
	mana.unlock()  # thanh mana xuất hiện, luôn bắt đầu ở 0


## Mana đầy: ô R trở thành Ultimate nâng cấp và hồi chiêu được reset ngay.
func _on_mana_full() -> void:
	SpellSystem.reset_cooldown(SpellSystem.get_ultimate())
	ultimate_ready.emit()


## Enemy gọi hàm này khi bị Player đánh trúng (xem Enemy._notify_damage_source): nạp mana.
func on_dealt_damage(_target: Node, killed: bool) -> void:
	if mana == null:
		return
	var tuning := CombatTuning.current()
	mana.gain(tuning.mana_per_kill if killed else tuning.mana_per_hit)


func is_rushing() -> bool:
	return _is_rushing


## Bắt đầu lao đấm về phía con trỏ. Đủ mana -> bản Ultimate (tiêu toàn bộ mana), không đủ -> bản thường.
func _start_rush(spell: SpellData) -> bool:
	if _is_rushing or _is_dashing or _caster.is_busy() or _root_timer > 0.0:
		return false  # đang bị trói thì không lao được
	_rush_upgraded = mana != null and mana.is_full() and spell.ult_shockwave != null
	if _rush_upgraded:
		mana.consume()
	_rush_spell = spell
	_rush_dir = _get_aim_direction()
	_rush_duration = maxf(spell.ult_duration if _rush_upgraded else spell.rush_duration, 0.05)
	var distance := spell.ult_distance if _rush_upgraded else spell.rush_distance
	_rush_speed = distance / _rush_duration
	_rush_elapsed = 0.0
	_rush_jabs_done = 0
	_rush_trail_timer = 0.0
	_is_rushing = true
	_is_casting = false
	_knockback = Vector2.ZERO
	last_direction = _rush_dir
	SpellSystem.start_cooldown(spell, spell.ult_cooldown if _rush_upgraded else spell.cooldown)
	_rush_iframe_timer = _rush_duration + rush_iframe_extra
	if _using_character_frames:
		_play_key("cast", true)
		var anim_name := animated_sprite.animation
		var frames := animated_sprite.sprite_frames
		if frames.has_animation(anim_name):
			var anim_length := frames.get_frame_count(anim_name) / maxf(frames.get_animation_speed(anim_name), 0.01)
			animated_sprite.speed_scale = clampf(anim_length / _rush_duration, 1.0, max_cast_anim_speed)
	rush_started.emit(_rush_upgraded)
	spell_cast.emit(spell)
	return true


func _process_rush(delta: float) -> void:
	_rush_elapsed += delta
	velocity = _rush_dir * _rush_speed
	_rush_trail_timer -= delta
	if _rush_trail_timer <= 0.0:
		_rush_trail_timer = dash_trail_interval
		_spawn_trail_ghost(rush_trail_color)
	# Bản Ultimate: đấm liên tiếp dọc đường lao, rải đều theo thời gian.
	if _rush_upgraded and _rush_spell.ult_jab != null:
		var jabs := maxi(_rush_spell.ult_jab_count, 1)
		while _rush_jabs_done < jabs and _rush_elapsed >= _rush_duration * float(_rush_jabs_done + 1) / float(jabs + 1):
			_rush_jabs_done += 1
			_spawn_rush_burst(_rush_spell.ult_jab, global_position + _rush_dir * _rush_spell.punch_offset)
			ultimate_impact.emit(global_position, 2.5, false)
	if _rush_elapsed >= _rush_duration:
		_end_rush()


func _end_rush() -> void:
	if not _is_rushing:
		return
	_is_rushing = false
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	var spell := _rush_spell
	if spell != null:
		if _rush_upgraded:
			# Chấn động ở điểm cuối: đẩy lùi mọi Enemy trong vùng, kể cả Boss.
			_spawn_rush_burst(spell.ult_shockwave, global_position + _rush_dir * spell.punch_offset * 0.5)
			ultimate_impact.emit(global_position, 16.0, true)
		elif spell.rush_punch != null:
			_spawn_rush_burst(spell.rush_punch, global_position + _rush_dir * spell.punch_offset)
			ultimate_impact.emit(global_position, 6.0, false)
	_dash_lag_timer = ultimate_end_lag if _rush_upgraded else rush_end_lag


func _cancel_rush() -> void:
	_is_rushing = false
	_rush_iframe_timer = 0.0
	animated_sprite.speed_scale = 1.0


func _spawn_rush_burst(burst_spell: SpellData, pos: Vector2) -> void:
	var parent_node := get_parent()
	if burst_spell == null or parent_node == null:
		return
	var burst := SpellAreaBurst.new()
	burst.setup(burst_spell, &"player", self, PlayerStats.damage_multiplier())
	burst.delay_override = 0.0
	parent_node.add_child(burst)
	burst.global_position = pos


func _cache_mouse_bound_slots() -> void:
	_mouse_bound_slots.clear()
	for action in SPELL_ACTIONS:
		var bound := false
		for event in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				bound = true
		_mouse_bound_slots.append(bound)


## Hướng ngắm: từ Player tới con trỏ chuột. Chuột quá sát Player thì dùng hướng nhìn hiện tại.
func _get_aim_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 4.0:
		return last_direction
	return to_mouse.normalized()


func _on_cast_started(spell: SpellData, direction: Vector2) -> void:
	_is_casting = true
	last_direction = direction  # quay mặt theo hướng ngắm
	if not _using_character_frames:
		return
	_play_key("cast", true)
	# Tăng tốc animation cast để vừa thời gian cast + hồi (chỉ tăng, không làm chậm).
	var anim_name := animated_sprite.animation
	var frames := animated_sprite.sprite_frames
	if frames.has_animation(anim_name) and String(anim_name).begins_with("cast_"):
		var anim_length := frames.get_frame_count(anim_name) / maxf(frames.get_animation_speed(anim_name), 0.01)
		var total := spell.cast_time + spell.recovery_time
		if total > 0.0 and anim_length > total:
			animated_sprite.speed_scale = minf(anim_length / total, max_cast_anim_speed)


func _on_spell_fired(spell: SpellData) -> void:
	SpellSystem.start_cooldown(spell)  # cooldown chỉ bắt đầu khi spell thật sự được bắn
	spell_cast.emit(spell)


func _on_cast_ended() -> void:
	_is_casting = false
	animated_sprite.speed_scale = 1.0


func _on_cast_interrupted(_spell: SpellData) -> void:
	_on_cast_ended()


# ---------------------------------------------------------------- Máu
## Enemy, đạn... gọi hàm này để gây sát thương. info (tùy chọn) mang loại sát thương và lực đẩy lùi.
func take_damage(amount: float, info: DamageInfo = null) -> void:
	if is_dead:
		return
	if _shield_timer > 0.0:
		return  # trường bảo hộ Shockwave Shield: miễn nhiễm mọi sát thương (và hiệu ứng choáng/trói đi kèm)
	if _rush_iframe_timer > 0.0:
		return  # đang lao đấm: bất tử, nhưng không thưởng né hoàn hảo
	if _dash_iframe_timer > 0.0:
		_try_perfect_dodge(amount)  # đòn trúng vào khung bất tử của dash: có thể là "né hoàn hảo"
		return
	if _invulnerable_timer > 0.0:
		return
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, health)
	ComboSystem.register_player_damaged()
	CombatFx.spawn_damage_number(get_parent(), global_position + Vector2(0.0, -30.0), amount, DamageInfo.Type.PHYSICAL, true)
	if health <= 0.0:
		_die()
		return
	_invulnerable_timer = invulnerable_time
	_flash()
	if info != null and not _is_dashing:
		apply_knockback(info.knockback)
	if info != null and (info.stun_time > 0.0 or info.root_time > 0.0):
		apply_status(info.stun_time, info.root_time)
	_caster.interrupt()  # chỉ spell có interruptible = true mới bị ngắt


## Gây trạng thái bất lợi (giây). Bị chặn khi đang miễn nhiễm (ngay sau một lần choáng/trói). Lướt hay lao đấm đang chạy bị hủy.
func apply_status(stun_time: float, root_time: float) -> void:
	if is_dead or _status_immunity > 0.0:
		return
	if stun_time > 0.0:
		_stun_timer = maxf(_stun_timer, stun_time)
		if _is_dashing:
			_end_dash()
		if _is_rushing:
			_cancel_rush()
		_caster.reset()
		_is_casting = false
		CombatFx.spawn_text(get_parent(), global_position + Vector2(0.0, -56.0), "CHOÁNG", Color(0.7, 0.9, 1.0), 16)
	if root_time > 0.0:
		_root_timer = maxf(_root_timer, root_time)
		if _is_dashing:
			_end_dash()
		CombatFx.spawn_text(get_parent(), global_position + Vector2(0.0, -56.0), "BỊ TRÓI", Color(0.6, 1.0, 0.7), 16)
	_apply_status_tint()


## Đếm ngược trạng thái; hết choáng/trói thì khôi phục màu và bật miễn nhiễm ngắn.
func _update_status(delta: float) -> void:
	if _stun_timer <= 0.0 and _root_timer <= 0.0:
		return
	var was_stunned := _stun_timer > 0.0
	var was_rooted := _root_timer > 0.0
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_root_timer = maxf(_root_timer - delta, 0.0)
	if (was_stunned and _stun_timer <= 0.0) or (was_rooted and _root_timer <= 0.0):
		_status_immunity = status_immunity_time
	_apply_status_tint()


func _apply_status_tint() -> void:
	if animated_sprite == null:
		return
	if _stun_timer > 0.0:
		animated_sprite.modulate = Color(0.6, 0.85, 1.35)
	elif _root_timer > 0.0:
		animated_sprite.modulate = Color(0.65, 1.2, 0.7)
	else:
		animated_sprite.modulate = Color.WHITE


func is_stunned() -> bool:
	return _stun_timer > 0.0


func is_rooted() -> bool:
	return _root_timer > 0.0


## Đẩy lùi Player (pixel/giây). Giảm dần theo knockback_decay.
func apply_knockback(impulse: Vector2) -> void:
	_knockback = (impulse * CombatTuning.current().knockback_multiplier).limit_length(max_knockback_speed)


## Né hoàn hảo: lướt đúng lúc để một đòn đáng kể trúng vào khung bất tử. Thưởng: hoàn lại một lượt lướt (và slow-mo do GameFeel).
## Có giãn cách tối thiểu giữa 2 lần để không thể lạm dụng bằng cách lướt liên tục vào đạn.
func _try_perfect_dodge(amount: float) -> void:
	var tuning := CombatTuning.current()
	if not tuning.perfect_dodge_enabled or _perfect_cd > 0.0 or amount < tuning.perfect_dodge_min_damage:
		return
	_perfect_cd = tuning.perfect_dodge_cooldown
	if tuning.perfect_dodge_refund_dash:
		var max_charges := maxi(dash_max_charges, 1)
		_dash_charges = mini(_dash_charges + 1, max_charges)
		if _dash_charges >= max_charges:
			_dash_recharge_timer = 0.0
	CombatFx.spawn_text(get_parent(), global_position + Vector2(0.0, -48.0), "NÉ HOÀN HẢO", Color(0.55, 0.9, 1.0), 16)
	ComboSystem.register_perfect_dodge()
	perfect_dodge.emit()


var _base_max_health: float = -1.0


## Áp dụng relic lên chỉ số của Player (máu tối đa). Gọi khi vào map, hồi sinh, mua/bán relic. Máu hiện tại tăng cùng phần máu tối đa vừa tăng.
func refresh_stats() -> void:
	if _base_max_health < 0.0:
		_base_max_health = max_health
	var new_max := _base_max_health * PlayerStats.max_health_multiplier()
	var diff := new_max - max_health
	max_health = new_max
	health = clampf(health + maxf(diff, 0.0), 0.0, max_health)


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, max_health)


## Hồi sinh và đầy máu (dùng khi bắt đầu lượt chơi mới).
func revive() -> void:
	is_dead = false
	refresh_stats()
	health = max_health
	_invulnerable_timer = 0.0
	_stun_timer = 0.0
	_root_timer = 0.0
	_status_immunity = 0.0
	_shield_timer = 0.0
	for old in get_children():
		if old is ShieldBubble:
			old.queue_free()
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_caster.reset()
	_is_casting = false
	_cancel_dash()
	_cancel_rush()
	if mana != null and not SpellSystem.has_ultimate():
		mana.lock()  # lượt chơi mới (đã xóa Ultimate): thanh mana biến mất
	_dash_charges = maxi(dash_max_charges, 1)
	_dash_recharge_timer = 0.0
	_dash_buffer_timer = 0.0
	_dash_lag_timer = 0.0
	_spell_buffer.fill(0.0)
	animated_sprite.modulate = Color.WHITE
	update_animation()


func _die() -> void:
	if is_dead:  # chặn phát signal died 2 lần
		return
	is_dead = true
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_caster.reset()
	_is_casting = false
	_cancel_dash()
	_cancel_rush()
	if _using_character_frames:
		_play_key("die", true)
	died.emit()


func _flash() -> void:
	animated_sprite.modulate = Color(1.0, 0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)


# ---------------------------------------------------------------- Va chạm
func _setup_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		push_warning("Player: không có node CollisionShape2D.")
		return
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape_node.shape = circle
	shape_node.scale = Vector2.ONE  # scale lên CollisionShape2D dễ gây va chạm sai, không dùng
	shape_node.position = body_offset


# ---------------------------------------------------------------- Animation
func _setup_animations() -> void:
	var sheets := {"idle": "Idle", "move": move_animation, "die": "Die", "cast": "CastSpell", "dash": "Rolling"}
	var loops := {"idle": true, "move": true, "die": false, "cast": false, "dash": false}
	var frames := CharacterFrames.build(character_folder, sheets, loops, frame_size, anim_fps)
	if frames == null:
		push_warning("Player: không dựng được animation từ '%s', dùng animation cũ." % character_folder)
		return
	animated_sprite.sprite_frames = frames
	_using_character_frames = true
	update_animation()


func update_animation() -> void:
	if _using_character_frames:
		if _is_casting or _is_dashing or _is_rushing:
			return  # animation cast / dash / lao đấm đang chạy riêng, xong thì quay lại idle/move
		_play_key("move" if _input_direction != Vector2.ZERO else "idle")
	else:
		_play(get_direction_animation(last_direction))


## Phát animation theo loại ("idle", "move", "die", "cast") và hướng nhìn hiện tại.
## restart = true: luôn phát lại từ đầu (dùng cho cast, die).
func _play_key(key: String, restart: bool = false) -> void:
	var anim_name := "%s_%d" % [key, CharacterFrames.direction_row(last_direction)]
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		anim_name = "%s_0" % key
		if not animated_sprite.sprite_frames.has_animation(anim_name):
			return
	_play(anim_name, restart)


## Đổi sang animation mới. Khi chỉ đổi HƯỚNG (cùng loại, ví dụ move_3 -> move_4) thì giữ nguyên khung hình
## đang chạy để không bị giật về khung đầu mỗi lần đổi hướng.
func _play(animation_name: String, restart: bool = false) -> void:
	if not restart and animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	var old_name := String(animated_sprite.animation)
	var keep_frame := not restart and animated_sprite.is_playing() and _anim_key(old_name) == _anim_key(animation_name)
	var old_frame := animated_sprite.frame
	var old_progress := animated_sprite.frame_progress
	animated_sprite.play(animation_name)
	if keep_frame and old_frame < animated_sprite.sprite_frames.get_frame_count(animation_name):
		animated_sprite.set_frame_and_progress(old_frame, old_progress)


## "move_3" -> "move". Tên không có dấu "_" thì giữ nguyên.
func _anim_key(animation_name: String) -> String:
	var cut := animation_name.rfind("_")
	return animation_name.substr(0, cut) if cut > 0 else animation_name


# --- Chỉ dùng khi không dựng được animation mới (animation cũ của Knight trong Player.tscn)
func get_direction_animation(direction: Vector2) -> String:
	var x := direction.x
	var y := direction.y

	if y > 0:
		if x > 0:
			return "idle_down_right"
		elif x < 0:
			return "idle_down_left"
		return "idle_down"
	elif y < 0:
		if x > 0:
			return "idle_up_right"
		elif x < 0:
			return "idle_up_left"
		return "idle_up"
	else:
		if x > 0:
			return "idle_right"
		elif x < 0:
			return "idle_left"

	return "idle_down"
