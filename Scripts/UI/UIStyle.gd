class_name UIStyle
extends RefCounted
## Style bo góc dùng chung cho toàn bộ giao diện (panel, nút), để mọi chỗ có cùng một diện mạo.

const PANEL_BG := Color(0.07, 0.06, 0.1, 0.8)
const PANEL_BORDER := Color(0.9, 0.82, 0.65, 0.55)
const ACCENT := Color(1.0, 0.82, 0.35)


## Khung bo góc. radius lớn (>= nửa chiều cao) cho dạng viên thuốc.
static func box(radius: int = 12, bg: Color = PANEL_BG, border: Color = PANEL_BORDER, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.set_content_margin_all(8.0)
	sb.anti_aliasing = true
	return sb


## Panel bo góc cho PanelContainer/Panel.
static func apply_panel(panel: Control, radius: int = 14, margin: float = 10.0) -> void:
	var sb := box(radius)
	sb.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", sb)


## Nút bo góc với 3 trạng thái: thường, rê chuột, bấm. Không viền focus (tránh viền vuông khi bấm Enter).
static func apply_button(button: Button, radius: int = 12, font_size: int = 14) -> void:
	button.add_theme_stylebox_override("normal", box(radius, Color(0.14, 0.12, 0.2, 0.92)))
	button.add_theme_stylebox_override("hover", box(radius, Color(0.24, 0.2, 0.34, 0.96), ACCENT))
	button.add_theme_stylebox_override("pressed", box(radius, Color(0.1, 0.08, 0.14, 1.0), ACCENT))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	button.focus_mode = Control.FOCUS_NONE


## Chữ có viền đen cho dễ đọc trên mọi nền.
static func apply_label(label: Label, font_size: int, outline: int = 4, color: Color = Color.WHITE) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline)
