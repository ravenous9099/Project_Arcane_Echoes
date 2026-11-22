class_name SkillVfx
extends Node2D
## Hiệu ứng hình của kỹ năng nhiều bước: phát chuỗi ảnh (pixel-art lọc NEAREST) tại một điểm hoặc bám theo một node.
##  - loop = false: phát MỘT lần rồi tự xóa. duration > 0 thì kéo giãn/co lại cho vừa đúng duration giây.
##  - loop = true : lặp tới hết duration (mờ dần ở 0.25 giây cuối). duration <= 0 thì lặp mãi tới khi gọi stop().
## Không có ảnh thì vẽ hình tròn mờ dần theo màu (placeholder rõ ràng), tồn tại duration (hoặc 0.3 giây).

const FADE_TIME: float = 0.25
const FALLBACK_TIME: float = 0.3

var _folder: String = ""
var _sprite_scale: float = 2.0
var _fps: float = 16.0
var _loop: bool = false
var _duration: float = 0.0
var _color: Color = Color.WHITE
var _radius: float = 24.0
var _follow: Node2D = null
var _follow_offset: Vector2 = Vector2.ZERO
var _sprite: AnimatedSprite2D = null
var _t: float = 0.0


## Tạo và thêm vào parent. rotation_rad: xoay sẵn (đã gồm độ lệch của ảnh).
static func spawn(parent: Node, folder: String, pos: Vector2, sprite_scale: float, fps: float, loop: bool, duration: float, rotation_rad: float = 0.0, color: Color = Color.WHITE, radius: float = 24.0) -> SkillVfx:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx := SkillVfx.new()
	fx._folder = folder
	fx._sprite_scale = sprite_scale
	fx._fps = fps
	fx._loop = loop
	fx._duration = duration
	fx._color = color
	fx._radius = radius
	parent.add_child(fx)
	fx.global_position = pos
	fx.rotation = rotation_rad
	return fx


## Bám theo node (hiệu ứng tích tụ năng lượng quanh người thi triển).
func follow(target: Node2D, offset: Vector2) -> void:
	_follow = target
	_follow_offset = offset


func stop() -> void:
	queue_free()


func _ready() -> void:
	z_index = 10
	var frames := VfxFrames.load_folder(_folder, _fps, _loop)
	if frames == null:
		queue_redraw()
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	if VfxFrames.is_pixel_folder(_folder):
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if not _loop:
		if _duration > 0.0:
			var natural := float(frames.get_frame_count("default")) / maxf(_fps, 0.01)
			_sprite.speed_scale = maxf(natural / _duration, 0.05)
		_sprite.animation_finished.connect(queue_free)
	_sprite.play("default")


func _process(delta: float) -> void:
	_t += delta
	if _follow != null:
		if is_instance_valid(_follow):
			global_position = _follow.global_position + _follow_offset
		else:
			queue_free()
			return
	if _sprite == null:
		if _t >= maxf(_duration, FALLBACK_TIME):
			queue_free()
		else:
			queue_redraw()
		return
	if _loop and _duration > 0.0:
		if _t >= _duration:
			queue_free()
			return
		var left := _duration - _t
		if left < FADE_TIME:
			modulate.a = left / FADE_TIME


func _draw() -> void:
	if _sprite != null:
		return
	var k := clampf(_t / maxf(_duration, FALLBACK_TIME), 0.0, 1.0)
	var r := _radius * (0.4 + 0.6 * k)
	var c := _color
	c.a = 1.0 - k
	draw_circle(Vector2.ZERO, r, Color(c, c.a * 0.4))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 2.0)
