class_name PixelBar
extends Control
## Thanh chỉ số dạng viên thuốc bo tròn (máu Player, máu Boss, tiến độ điểm...): nền tối, viền, vệt sáng phía trên,
## phần "vừa mất" (chip) tụt dần sau một nhịp trễ, nháy viền khi bị mất, đổi màu và nhấp nháy khi thấp.
## Vẽ bằng StyleBoxFlat bo góc nên không cần file ảnh. (Tên lớp giữ nguyên PixelBar để không phải sửa các file khác.)

@export var fill_color: Color = Color(0.85, 0.2, 0.25)
## Màu khi giá trị xuống dưới low_threshold.
@export var low_fill_color: Color = Color(1.0, 0.3, 0.15)
## Phần vừa mất đi (tụt dần về giá trị hiện tại).
@export var chip_color: Color = Color(1.0, 0.92, 0.55)
@export var back_color: Color = Color(0.08, 0.06, 0.1, 0.9)
@export var border_color: Color = Color(0.95, 0.9, 0.8, 0.9)
## 0 = không cảnh báo thấp (dùng cho thanh tiến độ).
@export_range(0.0, 1.0, 0.01) var low_threshold: float = 0.3
@export var show_text: bool = true
@export var font_size: int = 11
## Thời gian chờ trước khi phần "vừa mất" bắt đầu tụt (giây).
@export var chip_delay: float = 0.35
## Tốc độ tụt, tính theo tỉ lệ chiều dài thanh mỗi giây.
@export var chip_speed: float = 1.2
## Nội dung chữ tùy chỉnh. Để trống thì hiện "giá trị / tối đa".
var custom_text: String = ""

var value: float = 100.0
var max_value: float = 100.0

var _chip_ratio: float = 1.0
var _chip_wait: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
var _last_ratio: float = 1.0
var _style_back := StyleBoxFlat.new()
var _style_fill := StyleBoxFlat.new()
var _style_outline := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_back.anti_aliasing = true
	_style_fill.anti_aliasing = true
	_style_outline.anti_aliasing = true
	_style_outline.draw_center = false
	_style_outline.set_border_width_all(2)


## Đặt giá trị hiện tại. Giá trị giảm thì kích hoạt nháy viền và hiệu ứng chip.
func set_values(new_value: float, new_max: float) -> void:
	max_value = maxf(new_max, 0.001)
	value = clampf(new_value, 0.0, max_value)
	var ratio := value / max_value
	if ratio < _last_ratio - 0.0001:
		_chip_wait = chip_delay
		_flash = 1.0
	if ratio > _chip_ratio:
		_chip_ratio = ratio  # hồi/tăng: chip đuổi kịp ngay
	_last_ratio = ratio


func get_ratio() -> float:
	return value / max_value


func _process(delta: float) -> void:
	_time += delta
	var ratio := get_ratio()
	if _chip_ratio > ratio:
		if _chip_wait > 0.0:
			_chip_wait -= delta
		else:
			_chip_ratio = maxf(ratio, _chip_ratio - chip_speed * delta)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var inner := rect.grow(-2.0)
	var radius := int(size.y * 0.5)
	var inner_radius := int(inner.size.y * 0.5)
	var ratio := get_ratio()

	_style_back.bg_color = back_color
	_style_back.set_corner_radius_all(radius)
	draw_style_box(_style_back, rect)

	if _chip_ratio > ratio:
		_draw_fill(inner, _chip_ratio, chip_color, inner_radius)
	var color := fill_color
	if low_threshold > 0.0 and ratio <= low_threshold and ratio > 0.0:
		color = low_fill_color.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_time * 8.0)))
	_draw_fill(inner, ratio, color, inner_radius)
	# Vệt sáng phía trên cho cảm giác khối
	var fill_w := inner.size.x * ratio
	if fill_w > 6.0:
		_style_fill.bg_color = Color(1, 1, 1, 0.22)
		_style_fill.set_corner_radius_all(int(inner.size.y * 0.18))
		draw_style_box(_style_fill, Rect2(inner.position + Vector2(3, 1), Vector2(fill_w - 6.0, maxf(inner.size.y * 0.32, 1.0))))

	_style_outline.border_color = border_color.lerp(Color(1.0, 0.3, 0.3), _flash)
	_style_outline.set_corner_radius_all(radius)
	draw_style_box(_style_outline, rect)

	if show_text:
		var text := custom_text if not custom_text.is_empty() else "%d / %d" % [ceili(value), int(max_value)]
		var font := get_theme_default_font()
		var baseline := size.y * 0.5 + font_size * 0.36
		draw_string_outline(font, Vector2(0.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)


func _draw_fill(area: Rect2, ratio: float, color: Color, radius: int) -> void:
	var width := area.size.x * ratio
	if width < 1.0:
		return
	_style_fill.bg_color = color
	_style_fill.set_corner_radius_all(mini(radius, int(width * 0.5)))
	draw_style_box(_style_fill, Rect2(area.position, Vector2(width, area.size.y)))
