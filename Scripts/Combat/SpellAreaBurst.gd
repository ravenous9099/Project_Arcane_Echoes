class_name SpellAreaBurst
extends Node2D
## Vùng nổ của spell dạng AREA. Sau area_delay giây (thời gian báo trước, có vòng tròn cảnh báo) sẽ gây sát thương
## MỘT lần lên mọi mục tiêu thuộc phe đối địch trong bán kính area_radius, rồi phát hiệu ứng và tự xóa.
## Kiểm tra bằng truy vấn vật lý (không dùng Area2D) nên đúng ngay frame kích hoạt.

var spell: SpellData
var team: StringName = &"player"
var source: Node2D = null
var damage_multiplier: float = 1.0

## Độ trễ riêng cho vùng nổ này (giây). < 0 thì dùng spell.area_delay. Boss dùng để thiên thạch rơi lần lượt.
var delay_override: float = -1.0

var _timer: float = 0.0
var _delay_total: float = 0.0
var _triggered: bool = false


func setup(p_spell: SpellData, p_team: StringName, p_source: Node2D, p_damage_multiplier: float = 1.0) -> void:
	spell = p_spell
	team = p_team
	source = p_source
	damage_multiplier = p_damage_multiplier


func _ready() -> void:
	if spell == null:
		push_error("SpellAreaBurst: chưa gọi setup() với SpellData.")
		queue_free()
		return
	_delay_total = delay_override if delay_override >= 0.0 else maxf(spell.area_delay, 0.0)
	_timer = _delay_total
	z_index = 5
	if team == &"enemy":
		add_to_group("enemy_attacks")  # để Boss/Encounter xóa sạch khi đổi giai đoạn hoặc khi Boss chết
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _triggered:
		return
	_timer -= delta
	if _timer > 0.0:
		queue_redraw()
		return
	_trigger()


func _draw() -> void:
	if spell == null or _triggered or _delay_total <= 0.05:
		return
	# Vòng cảnh báo: đầy dần theo thời gian chờ.
	var progress := 1.0 - clampf(_timer / _delay_total, 0.0, 1.0)
	var c := spell.color
	if team == &"enemy":
		# Vùng nguy hiểm của kẻ địch luôn là đỏ thẫm đậm, không phụ thuộc màu spell, để nổi trên mọi nền (tuyết, băng, cát).
		c = Color(0.72, 0.0, 0.1)
	c.a = 0.55 + 0.4 * progress
	draw_arc(Vector2.ZERO, spell.area_radius, 0.0, TAU, 48, Color(0, 0, 0, 0.7), 8.0)
	draw_arc(Vector2.ZERO, spell.area_radius, 0.0, TAU, 48, c, 4.5)
	draw_circle(Vector2.ZERO, spell.area_radius * progress, Color(c, 0.32))


## Người thi triển có thể đã chết trước khi vùng nổ kích hoạt: chỉ trả về nguồn nếu còn hợp lệ.
func _valid_source() -> Node2D:
	return source if is_instance_valid(source) else null


func _trigger() -> void:
	_triggered = true
	var circle := CircleShape2D.new()
	circle.radius = spell.area_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 1
	var target_group: StringName = &"enemies" if team == &"player" else &"player"
	var hits := get_world_2d().direct_space_state.intersect_shape(params, 64)
	var shooter := _valid_source()
	var damaged: Array[Node] = []
	for hit in hits:
		var body := hit.get("collider") as Node
		if body == null or (shooter != null and body == shooter) or damaged.has(body) or not body.is_in_group(target_group):
			continue
		damaged.append(body)
		var away := (body as Node2D).global_position - global_position
		var push_dir := away.normalized() if away.length_squared() > 0.01 else Vector2.RIGHT
		var info := DamageInfo.create(spell.damage * damage_multiplier, spell.damage_type, shooter, push_dir * spell.knockback_force, spell)
		info.force_knockback = spell.ignores_knockback_resistance
		info.stun_time = spell.stun_duration
		info.root_time = spell.root_duration
		info.apply_to(body)
	var fx_parent := get_parent()
	CombatFx.spawn_impact(fx_parent, spell.vfx_folder, global_position, spell.color, spell.vfx_scale, spell.vfx_fps, spell.area_radius)
	CombatFx.play_sound_at(fx_parent, spell.hit_sound, global_position)
	queue_free()
