class_name SkillRunner
extends RefCounted
## Chạy một kỹ năng nhiều bước (SpellData.steps). Không phải node: chỉ là tập hàm tĩnh + ngữ cảnh (Ctx).
## Bước có delay > 0 được hẹn giờ bằng SceneTreeTimer (tạm dừng cùng game). Bước tạo node vật lý chỉ được gọi từ
## timer / _physics_process / call_deferred, KHÔNG gọi trực tiếp trong callback va chạm (tránh lỗi "flushing queries").
## Phe: team "player" gây sát thương nhóm "enemies"; team "enemy" gây sát thương nhóm "player" (Enemy/Boss dùng được).

class Ctx extends RefCounted:
	var spell: SpellData
	var team: StringName = &"player"
	var source: Node2D = null
	var mult: float = 1.0
	var origin: Vector2 = Vector2.ZERO
	var aim_dir: Vector2 = Vector2.RIGHT
	var aim_pos: Vector2 = Vector2.ZERO
	## Chỉ dùng cho kỹ năng DASH: điểm bắt đầu và điểm đến của cú lướt.
	var path_from: Vector2 = Vector2.ZERO
	var path_to: Vector2 = Vector2.ZERO
	## Node chứa hiệu ứng/đạn (cùng cha với người thi triển để Y-Sort).
	var parent: Node = null

	func target_group() -> StringName:
		return &"enemies" if team == &"player" else &"player"

	func valid_source() -> Node2D:
		return source if is_instance_valid(source) else null

	func alive() -> bool:
		return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


static func make_ctx(spell: SpellData, team: StringName, source: Node2D, mult: float, origin: Vector2, aim_dir: Vector2, aim_pos: Vector2, parent: Node) -> Ctx:
	var ctx := Ctx.new()
	ctx.spell = spell
	ctx.team = team
	ctx.source = source
	ctx.mult = mult
	ctx.origin = origin
	ctx.aim_dir = aim_dir.normalized() if aim_dir != Vector2.ZERO else Vector2.RIGHT
	ctx.aim_pos = aim_pos
	ctx.parent = parent
	return ctx


## Chạy toàn bộ bước của spell.
static func start(ctx: Ctx, steps: Array[SkillStep]) -> void:
	for step in steps:
		if step == null:
			continue
		if step.delay > 0.0:
			_later(ctx, step.delay, func() -> void: run_step(ctx, step))
		else:
			run_step(ctx, step)


## Chạy MỘT bước cấp cao nhất: xác định điểm xuất hiện theo anchor rồi tạo bước tại đó.
static func run_step(ctx: Ctx, step: SkillStep) -> void:
	if not ctx.alive():
		return
	var dir := ctx.aim_dir
	var shared := {}
	var shift := step.pos_offset
	match step.anchor:
		SkillStep.Anchor.CASTER:
			spawn_at(ctx, step, ctx.origin + shift, dir, shared)
		SkillStep.Anchor.FRONT:
			spawn_at(ctx, step, ctx.origin + dir * step.offset + shift, dir, shared)
		SkillStep.Anchor.AIM:
			var target := ctx.aim_pos
			if step.max_range > 0.0 and ctx.origin.distance_to(target) > step.max_range:
				target = ctx.origin + (target - ctx.origin).normalized() * step.max_range
			spawn_at(ctx, step, target + shift, dir, shared)
		SkillStep.Anchor.PATH:
			var path := ctx.path_to - ctx.path_from
			var length := path.length()
			var path_dir := path.normalized() if length > 0.01 else dir
			var spacing := maxf(step.path_spacing, 8.0)
			var n := maxi(ceili(length / spacing), 1)
			for i in n:
				var point := ctx.path_from + path_dir * minf((float(i) + 0.5) * spacing, length)
				spawn_at(ctx, step, point + shift, path_dir, shared)


## Tạo bước tại pos (dùng cho cả bước cấp cao nhất lẫn on_end/trail của đạn). Bước có delay > 0 được hẹn giờ.
static func spawn_at(ctx: Ctx, step: SkillStep, pos: Vector2, dir: Vector2, shared: Dictionary = {}) -> void:
	if not ctx.alive() or step == null:
		return
	match step.type:
		SkillStep.Type.VFX:
			_spawn_vfx(ctx, step, pos, dir)
		SkillStep.Type.BURST:
			burst(ctx, step, pos, dir)
		SkillStep.Type.ZONE:
			var zone := SkillZone.new()
			zone.setup(ctx, step, shared)
			ctx.parent.add_child(zone)
			zone.global_position = pos
		SkillStep.Type.PROJECTILE:
			var n := maxi(step.count, 1)
			for i in n:
				var angle := 0.0
				if n > 1:
					angle = deg_to_rad(lerpf(-step.spread_deg * 0.5, step.spread_deg * 0.5, float(i) / float(n - 1)))
				var projectile := SkillProjectile.new()
				projectile.setup(ctx, step, dir.rotated(angle))
				ctx.parent.add_child(projectile)
				projectile.global_position = pos


## Chạy bước nối tiếp (on_end/trail) tại pos, có hỗ trợ delay.
static func spawn_follow_up(ctx: Ctx, step: SkillStep, pos: Vector2, dir: Vector2, shared: Dictionary = {}) -> void:
	if step == null:
		return
	if step.delay > 0.0:
		_later(ctx, step.delay, func() -> void: spawn_at(ctx, step, pos, dir, shared))
	else:
		spawn_at(ctx, step, pos, dir, shared)


static func _spawn_vfx(ctx: Ctx, step: SkillStep, pos: Vector2, dir: Vector2) -> void:
	var rot := 0.0
	if step.rotate_to_dir:
		rot = dir.angle()
	rot += deg_to_rad(step.vfx_rotation_offset_deg)
	SkillVfx.spawn(ctx.parent, step.vfx_folder, pos, step.vfx_scale, step.vfx_fps, step.vfx_loop, step.duration, rot, step.color, step.radius)


## Nổ tức thì: gây sát thương mọi mục tiêu đối địch trong radius (mỗi mục tiêu một lần), đẩy ra xa tâm nổ, kèm hiệu ứng hình.
static func burst(ctx: Ctx, step: SkillStep, pos: Vector2, dir: Vector2) -> void:
	if not ctx.alive():
		return
	if step.damage > 0.0 or step.knockback_force > 0.0:
		var circle := CircleShape2D.new()
		circle.radius = step.radius
		var params := PhysicsShapeQueryParameters2D.new()
		params.shape = circle
		params.transform = Transform2D(0.0, pos)
		params.collision_mask = 1
		var space := (ctx.parent as Node2D).get_world_2d().direct_space_state
		var hits := space.intersect_shape(params, 64)
		var shooter := ctx.valid_source()
		var group := ctx.target_group()
		var damaged: Array[Node] = []
		for hit in hits:
			var body := hit.get("collider") as Node
			if body == null or (shooter != null and body == shooter) or damaged.has(body) or not body.is_in_group(group):
				continue
			damaged.append(body)
			var away := (body as Node2D).global_position - pos
			var push_dir := away.normalized() if away.length_squared() > 16.0 else dir
			var info := DamageInfo.create(step.damage * ctx.mult, step.damage_type, shooter, push_dir * step.knockback_force, ctx.spell)
			info.force_knockback = ctx.spell != null and ctx.spell.ignores_knockback_resistance
			if ctx.spell != null:
				info.stun_time = ctx.spell.stun_duration
				info.root_time = ctx.spell.root_duration
			info.apply_to(body)
	_spawn_vfx(ctx, step, pos, dir)
	if ctx.spell != null:
		CombatFx.play_sound_at(ctx.parent, ctx.spell.hit_sound, pos)


static func _later(ctx: Ctx, seconds: float, action: Callable) -> void:
	if not ctx.alive():
		return
	ctx.parent.get_tree().create_timer(seconds, false).timeout.connect(action)
