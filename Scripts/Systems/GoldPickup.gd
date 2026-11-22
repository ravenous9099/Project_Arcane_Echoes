class_name GoldPickup
extends Area2D
## Đồng vàng rơi khi hạ Enemy. Văng ra một đoạn ngắn rồi nằm đó; Player lại gần thì đồng vàng bay về phía Player (nam châm) và được nhặt.
## Tạo hàng loạt bằng GoldPickup.spawn_drop(). Phải tạo bằng call_deferred khi gọi từ lúc Enemy chết (đang trong bước vật lý).

var value: int = 1
var lifetime: float = 30.0
var magnet_range: float = 110.0
var _velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _player: Node2D = null
var _seed: float = 0.0


## Rải `total` vàng thành `pieces` đồng quanh vị trí `pos` (đã nhân hệ số vàng của relic). Dùng call_deferred bên trong.
static func spawn_drop(parent_node: Node, pos: Vector2, total: int, pieces: int) -> void:
	if parent_node == null or total <= 0:
		return
	total = maxi(int(round(float(total) * PlayerStats.gold_multiplier())), 1)
	pieces = clampi(pieces, 1, total)
	var tuning := CombatTuning.current()
	var base := total / pieces
	var extra := total % pieces
	for i in pieces:
		var coin := GoldPickup.new()
		coin.value = base + (1 if i < extra else 0)
		coin.lifetime = tuning.gold_lifetime
		coin.magnet_range = tuning.gold_magnet_range
		var angle := randf() * TAU
		coin._velocity = Vector2.from_angle(angle) * randf_range(60.0, 170.0)
		parent_node.add_child.call_deferred(coin)
		coin.set_deferred("global_position", pos)


func _ready() -> void:
	add_to_group("gold_pickups")
	collision_layer = 0
	collision_mask = 1  # chỉ phát hiện Player (layer 1)
	_seed = randf() * TAU
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and _age > 0.25 and global_position.distance_to(_player.global_position) < magnet_range:
		var to_player := _player.global_position - global_position
		_velocity = _velocity.move_toward(to_player.normalized() * 520.0, 1800.0 * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, 340.0 * delta)
	global_position += _velocity * delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or bool(body.get("is_dead")):
		return
	Wallet.add(value)
	SfxPlayer.play_sfx(&"coin", -4.0)
	queue_free()


func _draw() -> void:
	var blink := lifetime > 0.0 and _age > lifetime - 4.0 and int(_age * 8.0) % 2 == 0
	if blink:
		return
	var bob := sin(_age * 6.0 + _seed) * 1.5
	var squash := absf(cos(_age * 4.0 + _seed))  # đồng xu xoay quanh trục dọc
	var c := Vector2(0.0, bob - 4.0)
	draw_circle(Vector2(0.0, 8.0), 6.0, Color(0, 0, 0, 0.3))  # bóng
	var rx := 3.0 + 4.5 * squash
	draw_set_transform(c, 0.0, Vector2(rx / 7.5, 1.0))
	draw_circle(Vector2.ZERO, 7.5, Color(0.55, 0.38, 0.05))
	draw_circle(Vector2.ZERO, 6.3, Color(1.0, 0.8, 0.2))
	draw_circle(Vector2(-1.5, -1.5), 3.0, Color(1.0, 0.95, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
