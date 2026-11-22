class_name SpellProjectile
extends Area2D
## Đạn của spell dạng PROJECTILE. Bay thẳng, gây sát thương qua DamageInfo, biến mất khi trúng vật cản,
## hết xuyên mục tiêu (pierce) hoặc hết thời gian sống. Được tạo bằng code từ SpellCaster, không cần scene riêng.
## Quy tắc trúng: team "player" chỉ gây sát thương nhóm "enemies"; team "enemy" chỉ gây sát thương nhóm "player".
## Đồng đội bị bỏ qua; mọi vật thể vật lý khác (cây, đá...) làm đạn nổ.

var spell: SpellData
var direction: Vector2 = Vector2.RIGHT
var team: StringName = &"player"
var source: Node2D = null
var damage_multiplier: float = 1.0

var _age: float = 0.0
var _hits_left: int = 1
var _finished: bool = false
var _hit_bodies: Array[Node] = []
var _sprite: AnimatedSprite2D = null


func setup(p_spell: SpellData, p_direction: Vector2, p_team: StringName, p_source: Node2D, p_damage_multiplier: float = 1.0) -> void:
	spell = p_spell
	direction = p_direction.normalized() if p_direction != Vector2.ZERO else Vector2.RIGHT
	team = p_team
	source = p_source
	damage_multiplier = p_damage_multiplier


func _ready() -> void:
	if spell == null:
		push_error("SpellProjectile: chưa gọi setup() với SpellData.")
		queue_free()
		return
	_hits_left = maxi(spell.pierce, 0) + 1
	if team == &"enemy":
		add_to_group("enemy_attacks")  # để Boss/Encounter xóa sạch khi đổi giai đoạn hoặc khi Boss chết
	collision_layer = 0
	collision_mask = 1  # phát hiện vật thể ở layer 1 (Player, Enemy, vật cản)
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = spell.projectile_radius
	shape.shape = circle
	add_child(shape)
	rotation = direction.angle() + deg_to_rad(spell.vfx_rotation_offset_deg)

	var frames := VfxFrames.load_folder(spell.vfx_folder, spell.vfx_fps, true)
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2(spell.vfx_scale, spell.vfx_scale)
		if VfxFrames.is_pixel_folder(spell.vfx_folder):
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		_sprite.play("default")
	else:
		queue_redraw()  # không có ảnh: vẽ hình tạm bằng màu của spell
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	if _sprite != null or spell == null:
		return
	draw_circle(Vector2.ZERO, spell.projectile_radius, spell.color)
	draw_arc(Vector2.ZERO, spell.projectile_radius * 1.4, 0.0, TAU, 24, spell.color.lightened(0.5), 2.0)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	global_position += direction * spell.projectile_speed * delta
	_age += delta
	if _age >= spell.projectile_lifetime:
		_finish(false)


func _on_body_entered(body: Node) -> void:
	var shooter := _valid_source()
	if _finished or (shooter != null and body == shooter) or _hit_bodies.has(body):
		return
	var target_group: StringName = &"enemies" if team == &"player" else &"player"
	if body.is_in_group(target_group):
		_hit_bodies.append(body)
		var info := DamageInfo.create(spell.damage * damage_multiplier, spell.damage_type, shooter, direction * spell.knockback_force, spell)
		info.stun_time = spell.stun_duration
		info.root_time = spell.root_duration
		info.apply_to(body)
		_hits_left -= 1
		if _hits_left <= 0:
			_finish(true)
	elif body.is_in_group("player") or body.is_in_group("enemies"):
		return  # đồng đội: đạn bay xuyên qua
	else:
		_finish(true)  # vật cản


## Người bắn có thể đã chết và bị giải phóng trong lúc đạn còn bay: chỉ trả về nguồn nếu còn hợp lệ.
func _valid_source() -> Node2D:
	return source if is_instance_valid(source) else null


## Kết thúc đạn. with_impact = true thì phát hiệu ứng va chạm và âm thanh trúng đòn.
func _finish(with_impact: bool) -> void:
	if _finished:
		return
	_finished = true
	if with_impact:
		var fx_parent := get_parent()
		CombatFx.spawn_impact(fx_parent, spell.impact_vfx_folder, global_position, spell.color, spell.vfx_scale, spell.vfx_fps, spell.projectile_radius * 3.0)
		CombatFx.play_sound_at(fx_parent, spell.hit_sound, global_position)
	queue_free()
