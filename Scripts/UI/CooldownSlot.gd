class_name CooldownSlot
extends Control
## Một ô bo góc trên thanh kỹ năng: dùng cho Spell (4 ô) và Dash (1 ô).
## Ba trạng thái nhìn là phân biệt được ngay:
##   TRỐNG    : khung xám tối, dấu "+" mờ, không có biểu tượng.
##   SẴN SÀNG : khung sáng theo màu spell, biểu tượng đủ màu, nháy trắng một lần khi vừa hồi xong.
##   ĐANG HỒI : biểu tượng xám tối, lớp phủ quét theo chiều kim đồng hồ (bo theo góc ô), số giây còn lại ở giữa.
## Biểu tượng spell lấy theo thứ tự: SpellData.icon -> khung hình giữa của VFX -> viên ngọc vẽ bằng code.

enum Mode { SPELL, DASH }
enum SlotState { EMPTY, READY, COOLDOWN }

const BG_COLOR := Color(0.06, 0.05, 0.08, 0.72)
const EMPTY_BORDER := Color(0.24, 0.24, 0.3, 0.7)
const COOLDOWN_BORDER := Color(0.34, 0.3, 0.34, 0.8)
## MỘT màu đỏ mặc định, dịu và mờ, dùng cho viền/nhấn của MỌI ô kỹ năng (không còn theo màu từng spell).
const HUD_RED := Color(0.72, 0.2, 0.22, 0.85)
const DASH_COLOR := HUD_RED
## Biểu tượng khi sẵn sàng hơi tối/mờ để HUD không lấn át màn chơi.
const READY_TINT := Color(0.86, 0.86, 0.86, 0.9)

@export var mode: Mode = Mode.SPELL
## Độ bo góc (pixel).
@export var corner_radius: int = 10
## Chữ phím hiện ở góc trái trên, ví dụ "Q", "LMB", "Space".
var key_text: String = ""
## true: ô đang ở dạng nâng cấp (Ultimate sẵn sàng): viền vàng nhấp nháy và nhãn "ULT".
var powered: bool = false

var _spell: SpellData = null
var _icon: Texture2D = null
var _ratio: float = 0.0
var _left: float = 0.0
var _charges: int = 1
var _max_charges: int = 1
var _usable: bool = true
var _prev_state: SlotState = SlotState.EMPTY
var _ready_flash: float = 0.0
var _style := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(42, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.anti_aliasing = true


## Cập nhật ô Spell. ratio: 0 = sẵn sàng, 1 = vừa dùng. left: số giây còn lại.
func refresh_spell(spell: SpellData, icon: Texture2D, ratio: float, left: float, usable: bool) -> void:
	_spell = spell
	_icon = icon
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if VfxFrames.icon_is_pixel(spell) else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	_ratio = ratio
	_left = left
	_usable = usable
	_track_state()


## Cập nhật ô Dash.
func refresh_dash(ratio: float, left: float, charges: int, max_charges: int, usable: bool) -> void:
	_ratio = ratio
	_left = left
	_charges = charges
	_max_charges = maxi(max_charges, 1)
	_usable = usable
	_track_state()


func get_slot_state() -> SlotState:
	if mode == Mode.SPELL:
		if _spell == null:
			return SlotState.EMPTY
		return SlotState.COOLDOWN if _ratio > 0.0 else SlotState.READY
	return SlotState.READY if _charges > 0 else SlotState.COOLDOWN


func _track_state() -> void:
	var state := get_slot_state()
	if _prev_state == SlotState.COOLDOWN and state == SlotState.READY:
		_ready_flash = 1.0  # vừa hồi xong: nháy một lần
	_prev_state = state


func _process(delta: float) -> void:
	_ready_flash = maxf(_ready_flash - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var pad := size.x * 0.1
	var inner := rect.grow(-pad)
	var state := get_slot_state()

	_style.draw_center = true
	_style.set_border_width_all(0)
	_style.bg_color = BG_COLOR
	_style.set_corner_radius_all(corner_radius)
	draw_style_box(_style, rect)

	var accent := HUD_RED

	match state:
		SlotState.EMPTY:
			var c := inner.get_center()
			draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), Color(1, 1, 1, 0.15), 2.0)
			draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color(1, 1, 1, 0.15), 2.0)
		_:
			var tint := READY_TINT if state == SlotState.READY else Color(0.3, 0.3, 0.36, 0.85)
			if mode == Mode.SPELL:
				_draw_spell_icon(inner, tint)
			else:
				_draw_dash_icon(inner, tint if state == SlotState.READY else Color(0.4, 0.45, 0.55))

	# Lớp phủ hồi chiêu: quét theo chiều kim đồng hồ từ đỉnh ô, bo theo góc ô
	if state == SlotState.COOLDOWN:
		_draw_sweep(rect.grow(-1.5), clampf(_ratio, 0.0, 1.0))
		if _left > 0.05:
			var text := "%.1f" % _left if _left < 10.0 else "%d" % ceili(_left)
			_draw_centered_text(text, rect.get_center(), 14)

	# Nháy khi vừa sẵn sàng
	if _ready_flash > 0.0:
		_style.bg_color = Color(1, 1, 1, 0.35 * _ready_flash)
		_style.set_corner_radius_all(corner_radius)
		draw_style_box(_style, rect.grow(-1.5))

	# Chốt đếm lượt dash (chỉ khi có nhiều hơn 1 lượt)
	if mode == Mode.DASH and _max_charges > 1:
		for i in _max_charges:
			var pip_pos := Vector2(inner.position.x + 2 + i * 8, inner.end.y - 6)
			draw_circle(pip_pos + Vector2(3, 3), 2.5, DASH_COLOR if i < _charges else Color(0.2, 0.2, 0.25))

	# Viền bo góc: sáng khi sẵn sàng, xám khi trống/đang hồi
	var border := accent if state == SlotState.READY else (EMPTY_BORDER if state == SlotState.EMPTY else COOLDOWN_BORDER)
	_style.draw_center = false
	_style.set_border_width_all(2)
	_style.border_color = border
	_style.set_corner_radius_all(corner_radius)
	draw_style_box(_style, rect)

	# Ultimate sẵn sàng: vòng sáng vàng nhấp nháy bên ngoài và nhãn "ULT" ở đáy ô.
	if powered and state == SlotState.READY:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		_style.draw_center = false
		_style.set_border_width_all(3)
		_style.border_color = Color(HUD_RED.r, HUD_RED.g, HUD_RED.b, 0.35 + 0.45 * pulse)
		_style.set_corner_radius_all(corner_radius)
		draw_style_box(_style, rect.grow(2.0))
		_draw_centered_text("ULT", Vector2(rect.get_center().x, rect.end.y - 7.0), 10)

	# Nhãn phím: viên thuốc nhỏ ở góc trái trên
	if not key_text.is_empty():
		var font := get_theme_default_font()
		var text_w := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		_style.draw_center = true
		_style.set_border_width_all(0)
		_style.bg_color = Color(0, 0, 0, 0.6)
		_style.set_corner_radius_all(6)
		draw_style_box(_style, Rect2(2, 2, text_w + 8, 12))
		draw_string(font, Vector2(6, 11), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.8))

	# Người chơi không thể dùng (đã chết...): phủ tối toàn ô
	if not _usable:
		_style.draw_center = true
		_style.set_border_width_all(0)
		_style.bg_color = Color(0, 0, 0, 0.5)
		_style.set_corner_radius_all(corner_radius)
		draw_style_box(_style, rect)


func _draw_spell_icon(area: Rect2, tint: Color) -> void:
	if _icon != null:
		var tex_size := _icon.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var k := minf(area.size.x / tex_size.x, area.size.y / tex_size.y)
			var draw_size := tex_size * k
			draw_texture_rect(_icon, Rect2(area.position + (area.size - draw_size) * 0.5, draw_size), false, tint)
			return
	# Không có ảnh: viên ngọc bo tròn vẽ bằng code, kèm chữ cái đầu của tên spell
	var base := HUD_RED * tint
	base.a = 1.0
	_style.draw_center = true
	_style.set_border_width_all(0)
	_style.bg_color = base.darkened(0.35)
	_style.set_corner_radius_all(corner_radius - 3)
	draw_style_box(_style, area)
	_style.bg_color = base
	draw_style_box(_style, area.grow(-3.0))
	if not _spell.display_name.is_empty():
		_draw_centered_text(_spell.display_name.substr(0, 1).to_upper(), area.get_center(), 16)


func _draw_dash_icon(area: Rect2, tint: Color) -> void:
	# Hai dấu ">" xếp liền nhau, gợi ý lướt về phía trước
	var c := area.get_center()
	for dx in [-6.0, 3.0]:
		var pts := PackedVector2Array([c + Vector2(dx - 4.0, -8.0), c + Vector2(dx + 4.0, 0.0), c + Vector2(dx - 4.0, 8.0)])
		draw_polyline(pts, tint, 3.0)


## Lớp phủ tối che phần chưa hồi xong, quét theo chiều kim đồng hồ từ đỉnh ô.
func _draw_sweep(area: Rect2, ratio: float) -> void:
	var overlay := Color(0, 0, 0, 0.62)
	if ratio <= 0.001:
		return
	var radius := float(corner_radius) - 1.5
	if ratio >= 0.999:
		_style.draw_center = true
		_style.set_border_width_all(0)
		_style.bg_color = overlay
		_style.set_corner_radius_all(int(radius))
		draw_style_box(_style, area)
		return
	var center := area.get_center()
	var half := area.size * 0.5
	var pts := PackedVector2Array([center])
	var start := -PI * 0.5
	var steps := maxi(int(ratio * 72.0), 2)
	for i in steps + 1:
		var angle := start + TAU * ratio * float(i) / float(steps)
		pts.append(center + _rounded_rect_edge(half, radius, angle))
	draw_colored_polygon(pts, overlay)


## Điểm nằm trên biên hình chữ nhật bo góc (nửa kích thước half, bán kính góc radius) theo hướng angle, tính từ tâm.
func _rounded_rect_edge(half: Vector2, radius: float, angle: float) -> Vector2:
	var dir := Vector2.from_angle(angle)
	var tx := half.x / maxf(absf(dir.x), 0.0001)
	var ty := half.y / maxf(absf(dir.y), 0.0001)
	var t := minf(tx, ty)
	var p := dir * t
	var corner := Vector2(half.x - radius, half.y - radius)
	if absf(p.x) > corner.x and absf(p.y) > corner.y:
		# Tia cắt vùng góc: tìm giao với đường tròn góc (tâm cc, bán kính radius)
		var cc := Vector2(signf(p.x) * corner.x, signf(p.y) * corner.y)
		var b := -dir.dot(cc)
		var c := cc.length_squared() - radius * radius
		var disc := b * b - c
		if disc >= 0.0:
			p = dir * (-b + sqrt(disc))
	return p


func _draw_centered_text(text: String, center: Vector2, font_size: int) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.36)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
