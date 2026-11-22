class_name SkillZone
extends Node2D
## Vùng cháy kéo dài (vệt lửa, wildfire...). Tồn tại step.duration giây, cứ ~0.1 giây kiểm tra mục tiêu đối địch đứng trong
## radius và gây step.damage cho mỗi mục tiêu tối đa một lần mỗi tick_interval. Nhiều vùng cùng một vệt dùng CHUNG bảng
## `shared` nên mục tiêu đứng chỗ hai vùng chồng nhau vẫn chỉ nhận sát thương một lần mỗi tick (đúng "14 sát thương mỗi giây").

const CHECK_INTERVAL: float = 0.1

var _ctx: SkillRunner.Ctx
var _step: SkillStep
var _shared: Dictionary = {}
var _age: float = 0.0
var _check: float = 0.0


func setup(ctx: SkillRunner.Ctx, step: SkillStep, shared: Dictionary) -> void:
	_ctx = ctx
	_step = step
	_shared = shared


func _ready() -> void:
	if _ctx == null or _step == null:
		queue_free()
		return
	if _ctx.team == &"enemy":
		add_to_group("enemy_attacks")  # Boss/Encounter xóa sạch khi đổi giai đoạn hoặc khi Boss chết
	var fx := SkillVfx.spawn(self, _step.vfx_folder, global_position, _step.vfx_scale, _step.vfx_fps, true, _step.duration, _step.vfx_rotation_offset_deg * PI / 180.0, _step.color, _step.radius)
	if fx != null:
		fx.position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _step.duration:
		queue_free()
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_INTERVAL
	_tick()


static func _clock() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _tick() -> void:
	if _step.damage <= 0.0:
		return
	var circle := CircleShape2D.new()
	circle.radius = _step.radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 1
	var hits := get_world_2d().direct_space_state.intersect_shape(params, 32)
	var shooter := _ctx.valid_source()
	var group := _ctx.target_group()
	var now := _clock()
	for hit in hits:
		var body := hit.get("collider") as Node
		if body == null or (shooter != null and body == shooter) or not body.is_in_group(group):
			continue
		var key := body.get_instance_id()
		if float(_shared.get(key, -1.0)) > now:
			continue
		_shared[key] = now + maxf(_step.tick_interval, 0.1) - 0.001
		var push := Vector2.ZERO
		if _step.knockback_force > 0.0:
			push = ((body as Node2D).global_position - global_position).normalized() * _step.knockback_force
		DamageInfo.create(_step.damage * _ctx.mult, _step.damage_type, shooter, push, _ctx.spell).apply_to(body)
