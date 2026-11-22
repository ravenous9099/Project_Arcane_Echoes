class_name FloatingText
extends Node2D
## Chữ nổi bay lên rồi mờ dần (số sát thương). Đặt vào thế giới (cùng cha với Enemy/Player), tự xóa khi hết thời gian.
## Vẽ bằng draw_string nên không tạo thêm node con. Tạo qua CombatFx.spawn_damage_number().

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 16
var life: float = 0.8
var rise: float = 34.0

var _age: float = 0.0


func setup(p_text: String, p_color: Color, p_font_size: int = 16, p_life: float = 0.8, p_rise: float = 34.0) -> void:
	text = p_text
	color = p_color
	font_size = p_font_size
	life = maxf(p_life, 0.1)
	rise = p_rise


func _ready() -> void:
	# Luôn nằm trên cùng, không bị Enemy khác (Y-sort) che.
	z_as_relative = false
	z_index = 100


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	var k := 1.0 - pow(1.0 - t, 3.0)  # bay lên nhanh rồi chậm dần
	var alpha := 1.0 if t < 0.6 else (1.0 - t) / 0.4
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - _age / 0.12)  # phóng to nhẹ lúc mới hiện
	draw_set_transform(Vector2(0.0, -rise * k), 0.0, Vector2(pop, pop))
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-width * 0.5, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
