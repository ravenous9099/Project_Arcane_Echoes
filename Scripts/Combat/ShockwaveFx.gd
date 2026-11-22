class_name ShockwaveFx
extends Node2D
## Hiệu ứng nhìn của Shockwave Shield: các vòng sóng chấn động lan ra tới bán kính ảnh hưởng, kèm những vệt "arc" điện
## gấp khúc tỏa theo mọi hướng. Chỉ để nhìn (không gây sát thương); tự xóa sau duration giây.
## Vẽ bằng code nên không cần file ảnh.

var radius: float = 128.0
var duration: float = 0.55
var color: Color = Color(0.45, 0.88, 1.0)

var _age: float = 0.0
var _bolts: Array[PackedVector2Array] = []  # mỗi vệt: các điểm đã tính sẵn (tỉ lệ 0..1 của bán kính, theo góc)


func _ready() -> void:
	z_index = 20
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 12:
		var angle := TAU * float(i) / 12.0 + rng.randf_range(-0.15, 0.15)
		var pts := PackedVector2Array()
		var dir := Vector2.from_angle(angle)
		var perp := Vector2(-dir.y, dir.x)
		var steps := 7
		for s in steps + 1:
			var t := float(s) / float(steps)
			var jitter := 0.0 if s == 0 or s == steps else rng.randf_range(-0.07, 0.07)
			pts.append(dir * (t if s < steps else rng.randf_range(0.85, 1.0)) + perp * jitter)
		_bolts.append(pts)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_age / duration, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - k, 3.0)
	var fade := 1.0 - k
	# Ba vòng sóng chấn động nối đuôi nhau.
	for ring in 3:
		var rk := clampf(ease_out * (1.0 + 0.0 * ring) - 0.16 * ring, 0.0, 1.0)
		if rk <= 0.0:
			continue
		var r := radius * rk
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(color, fade * (0.9 - 0.25 * ring)), 5.0 - 1.4 * ring)
	draw_circle(Vector2.ZERO, radius * ease_out, Color(color, 0.14 * fade))
	# Các vệt arc điện: lan ra nhanh hơn vòng sóng rồi tắt dần.
	var reach := clampf(k * 2.2, 0.0, 1.0)
	for bolt in _bolts:
		var pts := PackedVector2Array()
		for p in bolt:
			if p.length() <= reach + 0.02:
				pts.append(p * radius)
		if pts.size() >= 2:
			draw_polyline(pts, Color(color, 0.35 * fade), 7.0, true)
			draw_polyline(pts, Color(0.92, 1.0, 1.0, fade), 2.5, true)
	# Chớp sáng ở tâm lúc đầu.
	if k < 0.25:
		draw_circle(Vector2.ZERO, 26.0 * (1.0 - k * 4.0) + 6.0, Color(1, 1, 1, 0.8 * (1.0 - k * 4.0)))
