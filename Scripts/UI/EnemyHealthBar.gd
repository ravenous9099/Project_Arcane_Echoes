class_name EnemyHealthBar
extends Node2D
## Thanh máu nhỏ trên đầu Enemy (hoặc Boss). Enemy tự tạo thanh này trong _ready().
## Chỉ hiện sau khi bị đánh (always_visible = false), mờ dần sau show_time giây; có phần "vừa mất" tụt dần.
## Cần Enemy có: health, max_health, is_dead và signal damaged(amount, health_left).

var enemy: Node = null
var bar_width: float = 34.0
var bar_height: float = 5.0
var always_visible: bool = false
## Thời gian thanh còn hiện sau lần bị đánh cuối (giây).
var show_time: float = 3.0

var _timer: float = 0.0
var _chip_ratio: float = 1.0
var _chip_wait: float = 0.0


func setup(p_enemy: Node, width: float, offset: Vector2, p_always_visible: bool) -> void:
	enemy = p_enemy
	bar_width = width
	position = offset
	always_visible = p_always_visible


func _ready() -> void:
	z_as_relative = false
	z_index = 60  # nằm trên hình Enemy
	visible = always_visible
	set_process(always_visible)
	if enemy != null and enemy.has_signal("damaged"):
		enemy.connect("damaged", _on_damaged)


func _on_damaged(_amount: float, _health_left: float) -> void:
	_timer = show_time
	_chip_wait = 0.3
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
		visible = false
		set_process(false)
		return
	var ratio := _ratio()
	if _chip_ratio > ratio:
		if _chip_wait > 0.0:
			_chip_wait -= delta
		else:
			_chip_ratio = maxf(ratio, _chip_ratio - 1.5 * delta)
	_timer -= delta
	if not always_visible and _timer <= 0.0:
		visible = false
		set_process(false)
		return
	queue_redraw()


func _ratio() -> float:
	var max_health := float(enemy.get("max_health"))
	if max_health <= 0.0:
		return 0.0
	return clampf(float(enemy.get("health")) / max_health, 0.0, 1.0)


func _draw() -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var ratio := _ratio()
	var alpha := 1.0 if always_visible else clampf(_timer / 0.5, 0.0, 1.0)  # mờ dần nửa giây cuối
	var rect := Rect2(Vector2(-bar_width * 0.5, 0.0), Vector2(bar_width, bar_height))
	var inner := rect.grow(-1.0)
	draw_rect(rect, Color(0.05, 0.04, 0.07, 0.85 * alpha))
	if _chip_ratio > ratio:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * _chip_ratio, inner.size.y)), Color(1.0, 0.92, 0.55, alpha))
	var fill_color := Color(0.9, 0.25, 0.25) if ratio > 0.3 else Color(1.0, 0.55, 0.15)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), Color(fill_color, alpha))
	draw_rect(rect, Color(0.95, 0.9, 0.8, 0.9 * alpha), false, 1.0)
