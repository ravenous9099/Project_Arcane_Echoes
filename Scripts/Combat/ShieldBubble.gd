class_name ShieldBubble
extends Node2D
## Trường bảo hộ quanh Player trong lúc miễn nhiễm sát thương (Shockwave Shield). Là con của Player nên đi theo Player.
## Vòng sáng đập nhẹ, các mảnh lục giác xoay chậm; nhấp nháy nhanh trong 0,6 giây cuối để báo sắp hết.

var duration: float = 2.5
var bubble_radius: float = 46.0
var color: Color = Color(0.45, 0.88, 1.0)
var center_offset: Vector2 = Vector2(0.0, -8.0)

var _age: float = 0.0


func _ready() -> void:
	z_index = 15
	position = center_offset


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var left := duration - _age
	var intro := clampf(_age / 0.18, 0.0, 1.0)
	var alpha := intro
	if left < 0.6:
		alpha *= 0.4 + 0.6 * (0.5 + 0.5 * sin(_age * 30.0))
	var r := bubble_radius * (0.6 + 0.4 * intro) * (1.0 + 0.03 * sin(_age * 7.0))
	for g in 4:
		draw_circle(Vector2.ZERO, r * (1.0 - 0.06 * g), Color(color, (0.05 + 0.025 * g) * alpha))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color, 0.95 * alpha), 3.0)
	draw_arc(Vector2.ZERO, r * 0.93, 0.0, TAU, 56, Color(1, 1, 1, 0.4 * alpha), 1.5)
	var spin := _age * 0.9
	for i in 6:
		var a := spin + TAU * float(i) / 6.0
		var p0 := Vector2.from_angle(a) * r
		var p1 := Vector2.from_angle(a + TAU / 6.0) * r
		draw_line(p0, p1, Color(0.85, 0.98, 1.0, 0.55 * alpha), 2.0)
		draw_circle(p0, 3.0, Color(1, 1, 1, 0.9 * alpha))
