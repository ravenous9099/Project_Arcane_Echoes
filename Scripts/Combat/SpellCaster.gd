class_name SpellCaster
extends Node
## Thành phần dùng chung để "thi triển" spell. Gắn làm con của một Node2D (Player, sau này cả Enemy/Boss).
## Chỉ lo VIỆC THI TRIỂN: thời gian chuẩn bị (cast_time) -> tạo đạn/vùng nổ -> thời gian hồi (recovery_time).
## KHÔNG giữ danh sách spell hay cooldown: Player dùng SpellSystem cho việc đó (tránh hai hệ thống trùng nhau).
##
## Quy tắc (đang áp dụng):
##  - Đang chuẩn bị hoặc đang hồi thì KHÔNG thi triển được spell khác (không hủy bằng cách bấm spell khác).
##  - Cooldown bắt đầu khi spell THỰC SỰ được bắn (signal spell_fired), nên spell bị ngắt khi đang chuẩn bị thì không mất cooldown.
##  - Chỉ spell có interruptible = true mới bị ngắt khi nhận sát thương, và chỉ trong giai đoạn chuẩn bị.

signal cast_started(spell: SpellData, direction: Vector2)
## Đã tạo đạn/vùng nổ. Nơi nghe signal này sẽ bắt đầu cooldown.
signal spell_fired(spell: SpellData)
signal cast_finished
signal cast_interrupted(spell: SpellData)

enum State { IDLE, WINDUP, RECOVERY }

## "player" hoặc "enemy": quyết định phe bị đạn gây sát thương.
@export var team: StringName = &"player"
## Điểm bắn nằm cách tâm thân bấy nhiêu pixel theo hướng ngắm (tránh nổ ngay trong người).
@export var muzzle_distance: float = 14.0
## Dời điểm bắn (ví dụ lên ngang tay). Chỉnh nếu đạn trông bay ra không đúng chỗ.
@export var muzzle_offset: Vector2 = Vector2.ZERO

var damage_multiplier: float = 1.0
var state: State = State.IDLE
var current_spell: SpellData = null

var _timer: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _aim_pos: Vector2 = Vector2.ZERO
var _charge_vfx: SkillVfx = null


func is_busy() -> bool:
	return state != State.IDLE


## Cập nhật hướng/điểm ngắm (toạ độ thế giới). Player gọi mỗi frame; Enemy gọi với vị trí Player.
func set_aim(direction: Vector2, world_pos: Vector2) -> void:
	if direction != Vector2.ZERO:
		_aim_dir = direction.normalized()
	_aim_pos = world_pos


## Bắt đầu thi triển. Trả về false nếu đang bận hoặc không hợp lệ. KHÔNG kiểm tra cooldown (việc của người gọi).
func cast(spell: SpellData) -> bool:
	if spell == null or is_busy() or not (get_parent() is Node2D):
		return false
	current_spell = spell
	state = State.WINDUP
	_timer = maxf(spell.cast_time, 0.0)
	cast_started.emit(spell, _aim_dir)
	_start_charge_vfx(spell)
	if _timer <= 0.0:
		_fire()
	return true


## Ngắt spell đang chuẩn bị (nếu cho phép). Trả về true nếu thực sự bị ngắt.
func interrupt() -> bool:
	if state != State.WINDUP or current_spell == null or not current_spell.interruptible:
		return false
	var interrupted := current_spell
	_to_idle()
	cast_interrupted.emit(interrupted)
	return true


## Hủy mọi thứ không phát signal (dùng khi hồi sinh, chết, chơi lại).
func reset() -> void:
	_to_idle()


func _physics_process(delta: float) -> void:
	match state:
		State.WINDUP:
			_timer -= delta
			if _timer <= 0.0:
				_fire()
		State.RECOVERY:
			_timer -= delta
			if _timer <= 0.0:
				_finish()


func _fire() -> void:
	var spell := current_spell
	var body := get_parent() as Node2D
	if spell == null or body == null:
		_to_idle()
		return
	_clear_charge_vfx()
	var fx_parent := _world_parent(body)
	var origin := body.global_position + muzzle_offset + _aim_dir * muzzle_distance
	match spell.kind:
		SpellData.Kind.PROJECTILE:
			var projectile := SpellProjectile.new()
			projectile.setup(spell, _aim_dir, team, body, damage_multiplier)
			fx_parent.add_child(projectile)
			projectile.global_position = origin
		SpellData.Kind.RUSH, SpellData.Kind.SHIELD, SpellData.Kind.DASH:
			pass  # RUSH, SHIELD, DASH do Player tự xử lý (player.gd), SpellCaster không tạo gì
		SpellData.Kind.SKILL:
			var ctx := SkillRunner.make_ctx(spell, team, body, damage_multiplier, body.global_position + muzzle_offset, _aim_dir, _aim_pos, fx_parent)
			SkillRunner.start(ctx, spell.steps)
		SpellData.Kind.AREA:
			var burst := SpellAreaBurst.new()
			burst.setup(spell, team, body, damage_multiplier)
			fx_parent.add_child(burst)
			burst.global_position = _clamp_to_range(body.global_position, _aim_pos, spell.cast_range)
	CombatFx.play_sound_at(fx_parent, spell.cast_sound, origin)
	spell_fired.emit(spell)
	state = State.RECOVERY
	_timer = maxf(spell.recovery_time, 0.0)
	if _timer <= 0.0:
		_finish()


func _finish() -> void:
	_to_idle()
	cast_finished.emit()


## Hiệu ứng tích tụ năng lượng của kỹ năng: bám theo người thi triển suốt thời gian chuẩn bị.
func _start_charge_vfx(spell: SpellData) -> void:
	_clear_charge_vfx()
	var body := get_parent() as Node2D
	if spell.kind != SpellData.Kind.SKILL or spell.charge_vfx_folder.is_empty() or spell.cast_time <= 0.0 or body == null:
		return
	var offset := muzzle_offset + _aim_dir * spell.charge_offset
	_charge_vfx = SkillVfx.spawn(_world_parent(body), spell.charge_vfx_folder, body.global_position + offset, spell.charge_vfx_scale, spell.charge_vfx_fps, false, spell.cast_time, _aim_dir.angle(), spell.color)
	if _charge_vfx != null:
		_charge_vfx.follow(body, offset)


func _clear_charge_vfx() -> void:
	if _charge_vfx != null and is_instance_valid(_charge_vfx):
		_charge_vfx.queue_free()
	_charge_vfx = null


func _to_idle() -> void:
	_clear_charge_vfx()
	state = State.IDLE
	current_spell = null
	_timer = 0.0


## Đạn/vùng nổ được thêm vào cùng node cha với người thi triển (Entities, đã bật Y-Sort).
func _world_parent(body: Node2D) -> Node:
	var parent := body.get_parent()
	return parent if parent != null else get_tree().current_scene


func _clamp_to_range(from_pos: Vector2, target: Vector2, max_range: float) -> Vector2:
	if max_range <= 0.0:
		return target
	var offset := target - from_pos
	if offset.length() <= max_range:
		return target
	return from_pos + offset.normalized() * max_range
