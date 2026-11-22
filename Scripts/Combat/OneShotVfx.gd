class_name OneShotVfx
extends Node2D
## Hiệu ứng phát MỘT lần rồi tự xóa (va chạm, nổ...). Dùng chuỗi ảnh trong thư mục nếu có,
## nếu không có thì vẽ vòng tròn mờ dần theo màu của spell (hình tạm, rõ ràng là placeholder).

const FALLBACK_TIME: float = 0.25

var _folder: String = ""
var _color: Color = Color.WHITE
var _sprite_scale: float = 0.5
var _fps: float = 24.0
var _radius: float = 24.0
var _sprite: AnimatedSprite2D = null
var _t: float = 0.0


func setup(folder: String, color: Color, sprite_scale: float, fps: float, radius: float) -> void:
	_folder = folder
	_color = color
	_sprite_scale = sprite_scale
	_fps = fps
	_radius = radius


func _ready() -> void:
	z_index = 10
	var frames := VfxFrames.load_folder(_folder, _fps, false)
	if frames == null:
		queue_redraw()
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	if VfxFrames.is_pixel_folder(_folder):
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("default")


func _process(delta: float) -> void:
	if _sprite != null:
		return
	_t += delta
	if _t >= FALLBACK_TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _sprite != null:
		return
	var k := clampf(_t / FALLBACK_TIME, 0.0, 1.0)
	var r := _radius * (0.4 + 0.6 * k)
	var c := _color
	c.a = 1.0 - k
	draw_circle(Vector2.ZERO, r, Color(c, c.a * 0.4))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 2.0)
