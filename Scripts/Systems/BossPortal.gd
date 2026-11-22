class_name BossPortal
extends Node2D
## Cổng dịch chuyển tới phòng Boss (đặt ở giữa quảng trường lát đá của phòng xa điểm xuất phát nhất).
## Hình bệ lấy từ gói Pixel Art Top Down (không còn vẽ bằng code).
## Đang KHÓA: bệ tối màu kèm ổ khóa; chạm vào thì phát locked_touched (Main hiện thông báo còn thiếu bao nhiêu điểm).
## Đã MỞ: ánh sáng tím xoay; Player đứng trong vòng dwell_time giây thì phát activated (Main chạy hiệu ứng chuyển cảnh).

## Player đứng đủ lâu trong cổng đã mở.
signal activated
## Player chạm vào cổng đang khóa (tối đa mỗi touch_cooldown giây một lần).
signal locked_touched

## Ảnh bệ cổng (sprite #30 trong TX Props của gói Pixel Art Top Down - Basic) và vùng cắt.
const TEX: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Props.png")
const SRC := Rect2(352.0, 268.0, 96.0, 74.0)

@export var dwell_time: float = 0.6
@export var touch_cooldown: float = 2.5

var radius: float = 60.0
var unlocked: bool = false

var _area: Area2D
var _time: float = 0.0
var _dwell: float = 0.0
var _touch_timer: float = 0.0
var _fired: bool = false


func setup(p_radius: float) -> void:
	radius = p_radius


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Cùng mức z với nền; MapGenerator đặt cổng ngay trước node Entities nên cổng vẽ trên nền đất nhưng dưới nhân vật.
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1  # phát hiện Player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.7
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)


func unlock() -> void:
	unlocked = true
	_fired = false
	_dwell = 0.0


func lock() -> void:
	unlocked = false
	_fired = false
	_dwell = 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	_touch_timer = maxf(_touch_timer - delta, 0.0)
	var inside := false
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("player") and not bool(body.get("is_dead")):
			inside = true
			break
	if inside:
		if unlocked:
			_dwell += delta
			if _dwell >= dwell_time and not _fired:
				_fired = true
				activated.emit()
		elif _touch_timer <= 0.0:
			_touch_timer = touch_cooldown
			locked_touched.emit()
	else:
		_dwell = 0.0
	queue_redraw()


func _draw() -> void:
	# Bệ đá hình elip lấy từ gói Pixel Art Top Down (TX Props, sprite số 30, 96x74 px gốc). Đặt tâm bệ tại gốc node.
	var s := radius * 2.2 / SRC.size.x
	var half := SRC.size * s * 0.5
	var tint := Color.WHITE if unlocked else Color(0.55, 0.5, 0.62)
	draw_texture_rect_region(TEX, Rect2(-half, SRC.size * s), SRC, tint)
	# Tâm bệ (ô lõm giữa bệ) nằm lệch nhẹ so với tâm ảnh; vẽ hiệu ứng trong hệ tọa độ bị ép dẹt để ra hình elip.
	var c := Vector2(0.0, 1.0 * s)
	var r := 30.0 * s
	draw_set_transform(c, 0.0, Vector2(1.0, 0.74))
	if not unlocked:
		draw_circle(Vector2.ZERO, r, Color(0.08, 0.04, 0.12, 0.55))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.75, 0.25, 0.25, 0.85), 2.0 * s)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Ổ khóa: thân hình chữ nhật và quai tròn
		var k := maxf(s, 0.8)
		draw_rect(Rect2(c + Vector2(-8.0, -2.0) * k, Vector2(16.0, 13.0) * k), Color(0.85, 0.7, 0.3))
		draw_arc(c + Vector2(0.0, -2.0) * k, 6.0 * k, PI, TAU, 16, Color(0.85, 0.7, 0.3), 2.5 * k)
		return
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, r, Color(0.45, 0.25, 0.95, 0.35 + 0.2 * pulse))
	draw_circle(Vector2.ZERO, r * 0.55, Color(0.75, 0.6, 1.0, 0.4 + 0.25 * pulse))
	for i in 3:
		var start := _time * (1.2 + i * 0.5) + i * 2.1
		draw_arc(Vector2.ZERO, r * (0.55 + 0.17 * i), start, start + 1.6, 24, Color(0.9, 0.8, 1.0, 0.9), 2.0 * s)
	if _dwell > 0.0:  # vòng tiến độ khi đang đứng trong cổng
		draw_arc(Vector2.ZERO, r * 1.25, -PI * 0.5, -PI * 0.5 + TAU * clampf(_dwell / dwell_time, 0.0, 1.0), 48, Color.WHITE, 3.0 * s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Tia sáng bay lên từ tâm bệ.
	for i in 5:
		var ph := fposmod(_time * 0.6 + i * 0.2, 1.0)
		var x := sin(i * 2.7 + _time) * r * 0.5
		draw_circle(c + Vector2(x, -ph * r * 1.6), (1.0 - ph) * 2.6 * s, Color(0.85, 0.75, 1.0, (1.0 - ph) * 0.9))
