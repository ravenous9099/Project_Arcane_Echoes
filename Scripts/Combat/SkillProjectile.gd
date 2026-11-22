class_name SkillProjectile
extends Area2D
## Đạn của kỹ năng nhiều bước (SkillStep.Type.PROJECTILE). Bay thẳng tới max_range (hoặc điểm con trỏ nếu stop_at_aim),
## dừng khi trúng mục tiêu đối địch hoặc vật cản, rải vệt (trail) phía sau, rồi chạy các bước on_end tại điểm kết thúc.
## Sát thương chính thường nằm ở bước nổ trong on_end; step.damage > 0 thì còn gây thêm sát thương khi chạm.

var _ctx: SkillRunner.Ctx
var _step: SkillStep
var _dir: Vector2 = Vector2.RIGHT
var _travel_max: float = 256.0
var _travelled: float = 0.0
var _trail_acc: float = 0.0
var _trail_shared: Dictionary = {}
var _finished: bool = false
var _sprite: AnimatedSprite2D = null
var _started: bool = false
var _hits_left: int = 1
var _hit_bodies: Array[Node] = []


func setup(ctx: SkillRunner.Ctx, step: SkillStep, direction: Vector2) -> void:
	_ctx = ctx
	_step = step
	_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT


func _ready() -> void:
	if _ctx == null or _step == null:
		queue_free()
		return
	if _ctx.team == &"enemy":
		add_to_group("enemy_attacks")
	_hits_left = maxi(_step.pierce, 0) + 1
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _step.contact_radius
	shape.shape = circle
	add_child(shape)
	_travel_max = _step.max_range
	var frames := VfxFrames.load_folder(_step.vfx_folder, _step.vfx_fps, true)
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2(_step.vfx_scale, _step.vfx_scale)
		if VfxFrames.is_pixel_folder(_step.vfx_folder):
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _step.spin_deg_per_sec == 0.0 and _step.rotate_to_dir:
			rotation = _dir.angle() + deg_to_rad(_step.vfx_rotation_offset_deg)
		add_child(_sprite)
		_sprite.play("default")
	else:
		queue_redraw()
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	if _sprite != null or _step == null:
		return
	draw_circle(Vector2.ZERO, _step.contact_radius, _step.color)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	if not _started:
		# global_position chỉ được đặt SAU add_child (sau _ready) nên việc cần vị trí xuất phát làm ở frame đầu tiên.
		_started = true
		if _step.stop_at_aim:
			_travel_max = clampf(global_position.distance_to(_ctx.aim_pos), 16.0, _step.max_range)
		_drop_trail()  # vệt bắt đầu ngay tại điểm xuất phát
	var move := _step.speed * delta
	global_position += _dir * move
	_travelled += move
	if _sprite != null and _step.spin_deg_per_sec != 0.0:
		_sprite.rotation += deg_to_rad(_step.spin_deg_per_sec) * delta
	if _step.trail != null:
		_trail_acc += move
		while _trail_acc >= maxf(_step.trail_spacing, 6.0):
			_trail_acc -= maxf(_step.trail_spacing, 6.0)
			_drop_trail()
	if _travelled >= _travel_max:
		_end()


func _drop_trail() -> void:
	if _step.trail != null:
		SkillRunner.spawn_follow_up(_ctx, _step.trail, global_position, _dir, _trail_shared)


func _on_body_entered(body: Node) -> void:
	if _finished:
		return
	var shooter := _ctx.valid_source()
	if shooter != null and body == shooter:
		return
	if body.is_in_group(_ctx.target_group()):
		if _hit_bodies.has(body):
			return
		_hit_bodies.append(body)
		if _step.damage > 0.0:
			DamageInfo.create(_step.damage * _ctx.mult, _step.damage_type, shooter, _dir * _step.knockback_force, _ctx.spell).apply_to(body)
		_hits_left -= 1
		if _hits_left <= 0:
			_end()
	elif body.is_in_group("player") or body.is_in_group("enemies"):
		return  # đồng đội: bay xuyên qua
	else:
		_end()  # vật cản


## Dừng đạn, rồi (hoãn tới cuối frame vật lý) chạy các bước on_end tại điểm kết thúc.
func _end() -> void:
	if _finished:
		return
	_finished = true
	set_deferred("monitoring", false)
	call_deferred("_run_end_steps")


func _run_end_steps() -> void:
	for step in _step.on_end:
		SkillRunner.spawn_follow_up(_ctx, step, global_position, _dir)
	queue_free()
