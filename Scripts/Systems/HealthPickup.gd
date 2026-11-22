class_name HealthPickup
extends Area2D
## Viên máu rơi ra khi hạ Enemy (xác suất trong CombatTuning.hp_drop_chance). Player chạm vào thì hồi heal_amount máu.
## Tạo bằng code (Enemy._try_drop_health), không cần scene. Hình trái tim vẽ bằng code, nảy nhẹ và sáng nhấp nháy;
## nhấp nháy nhanh trong 5 giây cuối trước khi biến mất (lifetime).

@export var heal_amount: float = 20.0
## Giây tồn tại; 0 = không biến mất.
@export var lifetime: float = 25.0
@export var radius: float = 16.0

var _picked: bool = false
var _age: float = 0.0
var _heart: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	add_to_group("health_pickups")
	collision_layer = 0
	collision_mask = 1  # chỉ phát hiện Player (layer 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# Đường viền trái tim (tham số): x = 16 sin^3 t, y = -(13 cos t - 5 cos 2t - 2 cos 3t - cos 4t), thu nhỏ về bán kính ~ radius * 0.7.
	for i in 40:
		var t := TAU * float(i) / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		_heart.append(Vector2(x, y) * (radius * 0.7 / 16.0))


func _process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := sin(_age * 4.0) * 2.5
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)
	var blink := 1.0
	if lifetime > 0.0 and lifetime - _age < 5.0:
		blink = 0.35 + 0.65 * (0.5 + 0.5 * sin(_age * 18.0))
	var center := Vector2(0.0, -6.0 + bob)
	draw_circle(Vector2(0.0, 4.0), radius * 0.55, Color(0.0, 0.0, 0.0, 0.25 * blink))  # bóng dưới đất
	for g in 4:
		draw_circle(center, radius * (1.5 - 0.22 * g), Color(1.0, 0.25, 0.35, (0.05 + 0.03 * g) * (0.6 + 0.6 * pulse) * blink))
	var outline := PackedVector2Array()
	var body := PackedVector2Array()
	var shine := PackedVector2Array()
	for p in _heart:
		outline.append(center + p * 1.22)
		body.append(center + p)
		shine.append(center + p * 0.5 + Vector2(-radius * 0.18, -radius * 0.2))
	draw_colored_polygon(outline, Color(0.35, 0.02, 0.1, blink))
	draw_colored_polygon(body, Color(0.95, 0.15, 0.28, blink))
	draw_colored_polygon(shine, Color(1.0, 0.55, 0.62, 0.55 * blink))
	draw_circle(center + Vector2(-radius * 0.32, -radius * 0.28), radius * 0.1, Color(1, 1, 1, 0.9 * blink))
	draw_string(ThemeDB.fallback_font, Vector2(-12.0, center.y + radius * 1.3), "+%d" % int(heal_amount), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 11, Color(1.0, 0.85, 0.88, 0.85 * blink))


func _on_body_entered(body: Node) -> void:
	if _picked or not body.is_in_group("player") or not body.has_method("heal"):
		return
	if bool(body.get("is_dead")):
		return
	_picked = true
	body.call("heal", heal_amount)
	CombatFx.spawn_text(get_parent(), global_position + Vector2(0.0, -34.0), "+%d HP" % int(heal_amount), Color(1.0, 0.4, 0.5), 16)
	SfxPlayer.play_sfx(&"heal")
	queue_free()
