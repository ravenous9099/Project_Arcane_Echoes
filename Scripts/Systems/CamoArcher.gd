class_name CamoArcher
extends Enemy
## Xạ thủ ngụy trang (thay Archer thường ở Level 3). Giống Archer (giữ khoảng cách, bắn tên) nhưng:
##  - mũi tên băng: 15 sát thương + choáng Player 0,5 giây (xem Resources/EnemyAttacks/ice_arrow.tres);
##  - hòa vào tuyết: mờ đi khi đứng xa, hiện rõ khi chuẩn bị bắn, vừa bị đánh, hoặc khi Player lại gần.
## Phần ngụy trang chỉ đổi self_modulate của hình, không đụng tới logic Enemy.

@export_group("Ngụy trang")
## Độ đục (0..1) khi ẩn mình.
@export_range(0.05, 1.0, 0.05) var camo_alpha: float = 0.3
## Player lại gần hơn bấy nhiêu pixel thì thấy rõ.
@export var reveal_distance: float = 170.0
## Hiện rõ bấy nhiêu giây sau khi bị đánh trúng.
@export var reveal_after_hit: float = 1.2
## Tốc độ chuyển độ mờ (đơn vị alpha/giây).
@export var fade_speed: float = 3.5
@export var camo_tint: Color = Color(0.85, 0.93, 1.0)

var _reveal_timer: float = 0.0
var _current_alpha: float = 1.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _anim_sprite == null or _state == State.DEAD:
		return
	_reveal_timer = maxf(_reveal_timer - delta, 0.0)
	var visible_now := _reveal_timer > 0.0 or _state == State.ATTACK_PREP or _state == State.ATTACK \
			or _state == State.STUNNED
	if not visible_now and target != null and is_instance_valid(target):
		visible_now = global_position.distance_to(target.global_position) <= reveal_distance
	var goal := 1.0 if visible_now else camo_alpha
	_current_alpha = move_toward(_current_alpha, goal, fade_speed * delta)
	var hidden_amount := clampf((1.0 - _current_alpha) / maxf(1.0 - camo_alpha, 0.01), 0.0, 1.0)
	var tint := Color.WHITE.lerp(camo_tint, hidden_amount)
	tint.a = _current_alpha
	_anim_sprite.self_modulate = tint


func take_damage(amount: float, info: DamageInfo = null) -> void:
	_reveal_timer = reveal_after_hit
	super.take_damage(amount, info)
