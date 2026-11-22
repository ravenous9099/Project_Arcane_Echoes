class_name HubNpc
extends StaticBody2D
## NPC ở sảnh chờ: nhân vật pixel-art 2D vẽ riêng (không dùng spritesheet nhân vật 8 hướng), chỉ có animation Idle 4 khung nhìn thẳng về phía trước.
## Người Giữ Đèn: ông lão áo choàng xanh cầm gậy đèn lồng. Relic Merchant: thương nhân trùm mũ tím, ba lô đầy relic, tay nâng viên ngọc phát sáng.
## Ảnh: Resources/NPC/*_idle.png (4 khung 48x64 xếp ngang). Có thân va chạm tròn; Hub kiểm tra khoảng cách để hiện gợi ý "F: Nói chuyện".

enum Kind { LAMP_KEEPER, MERCHANT }

const SHEETS := {
	Kind.LAMP_KEEPER: "res://Resources/NPC/lamp_keeper_idle.png",
	Kind.MERCHANT: "res://Resources/NPC/merchant_idle.png",
}
const FRAME_SIZE := Vector2i(48, 64)
const FRAME_COUNT: int = 4
const IDLE_FPS: float = 4.0

var kind: Kind = Kind.LAMP_KEEPER
var display_name: String = ""
var interact_radius: float = 96.0
var _time: float = 0.0
var _highlight: float = 0.0
var _near: bool = false
var _sprite: AnimatedSprite2D = null


func setup(p_kind: Kind, p_name: String) -> void:
	kind = p_kind
	display_name = p_name


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	shape.position = Vector2(0.0, -6.0)
	add_child(shape)
	z_index = -1
	_time = randf() * 10.0
	_build_sprite()


func _build_sprite() -> void:
	var path: String = SHEETS[kind]
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("HubNpc: không tải được %s (cần để file trong Resources/NPC)." % path)
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", IDLE_FPS)
	frames.set_animation_loop("idle", true)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame("idle", atlas)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -FRAME_SIZE.y * 0.5 + 8.0)  # chân sprite chạm điểm đặt NPC
	add_child(_sprite)
	_sprite.play("idle")
	_sprite.frame = randi() % FRAME_COUNT


func set_near(value: bool) -> void:
	_near = value


func _process(delta: float) -> void:
	_time += delta
	_highlight = move_toward(_highlight, 1.0 if _near else 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	if _highlight > 0.01:
		draw_arc(Vector2(0.0, 4.0), 30.0 + 3.0 * sin(_time * 5.0), 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.8 * _highlight), 2.0)
		var label := "F · Nói chuyện"
		draw_string(f, Vector2(-70.0 + 1.0, -86.0 + 1.0), label, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 14, Color(0, 0, 0, _highlight))
		draw_string(f, Vector2(-70.0, -86.0), label, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 14, Color(1.0, 0.95, 0.7, _highlight))
	draw_string(f, Vector2(-80.0 + 1.0, 28.0 + 1.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 13, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-80.0, 28.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 13, Color(0.95, 0.92, 0.8))
