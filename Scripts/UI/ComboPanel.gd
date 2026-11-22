class_name ComboPanel
extends Control
## Bộ đếm combo dạng CHỮ (không còn khung) ở góc trái, dưới nút pause:
##  - Dòng 1: tổng số hit (số lớn nghiêng, viền dày) + chữ "HITS".
##  - Dòng 2: hạng combo (F..SSS) đổi màu theo hạng, nảy khi lên hạng, rung khi tụt hạng, kèm thanh tiến độ mảnh.
##  - Dòng 3: buff đang có, viết vắn tắt và nhỏ (ST = sát thương, HC = hồi chiêu, HP = máu mỗi lần hạ).
## Dữ liệu từ autoload ComboSystem.

var _pop: float = 0.0
var _shake: float = 0.0
var _flash: float = 0.0
var _hit_pop: float = 0.0
var _last_hits: int = 0
var _num_font: FontVariation
var _rank_font: FontVariation


func _init() -> void:
	custom_minimum_size = Vector2(250.0, 118.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Chữ đậm và nghiêng nhẹ (làm bằng FontVariation trên font mặc định).
	_num_font = FontVariation.new()
	_num_font.base_font = ThemeDB.fallback_font
	_num_font.variation_embolden = 0.7
	_num_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	_rank_font = FontVariation.new()
	_rank_font.base_font = ThemeDB.fallback_font
	_rank_font.variation_embolden = 0.9
	_rank_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.15, 1.0), Vector2.ZERO)


func _ready() -> void:
	_last_hits = ComboSystem.total_hits
	ComboSystem.rank_changed.connect(_on_rank_changed)
	ComboSystem.points_changed.connect(func(_p: int, _r: int) -> void: _flash = 1.0)


func _on_rank_changed(_rank: int, went_up: bool) -> void:
	if went_up:
		_pop = 1.0
	else:
		_shake = 1.0


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 3.0, 0.0)
	_shake = maxf(_shake - delta * 4.0, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_hit_pop = maxf(_hit_pop - delta * 6.0, 0.0)
	if ComboSystem.total_hits != _last_hits:
		if ComboSystem.total_hits > _last_hits:
			_hit_pop = 1.0
		_last_hits = ComboSystem.total_hits
	queue_redraw()


func _outlined(font: Font, pos: Vector2, text: String, fs: int, col: Color, outline: int = 6) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, outline, Color(0.02, 0.02, 0.06, col.a * 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


func _draw() -> void:
	var col := ComboSystem.get_rank_color()
	var hits := ComboSystem.total_hits
	var active := ComboSystem.points > 0 or hits > 0
	var alpha := 1.0 if active else 0.45

	# Dòng 1: số hit.
	var hit_text := str(hits)
	var hit_fs := int(round(44.0 + 10.0 * _hit_pop))
	var hit_col := Color(1.0, 1.0, 1.0, alpha).lerp(col, 0.25 * _hit_pop)
	_outlined(_num_font, Vector2(0.0, 44.0), hit_text, hit_fs, hit_col, 8)
	var tw := _num_font.get_string_size(hit_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, hit_fs).x
	_outlined(ThemeDB.fallback_font, Vector2(tw + 8.0, 44.0), "HITS", 16, Color(col, alpha * 0.9), 4)

	# Dòng 2: hạng + thanh tiến độ mảnh.
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0 * _shake
	var rank_text := ComboSystem.get_rank_name()
	var rank_fs := int(round(34.0 + 12.0 * _pop))
	_outlined(_rank_font, Vector2(0.0, 84.0) + shake, rank_text, rank_fs, Color(col, alpha).lerp(Color.WHITE, _flash * 0.4), 7)
	var rw := _rank_font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, rank_fs).x
	var bar := Rect2(rw + 12.0, 70.0, 110.0, 5.0)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55 * alpha))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ComboSystem.get_rank_progress(), bar.size.y)), Color(col, alpha))
	var idle := Rect2(bar.position.x, 78.0, bar.size.x, 2.0)
	draw_rect(idle, Color(0.0, 0.0, 0.0, 0.45 * alpha))
	draw_rect(Rect2(idle.position, Vector2(idle.size.x * ComboSystem.get_idle_ratio(), idle.size.y)), Color(1.0, 0.45, 0.35, 0.9 * alpha))

	# Dòng 3: buff viết tắt.
	var parts: Array[String] = []
	var dmg := ComboSystem.get_damage_bonus()
	if dmg > 0.0:
		parts.append("ST +%d%%" % int(round(dmg * 100.0)))
	var cd := ComboSystem.get_cooldown_reduction()
	if cd > 0.0:
		parts.append("HC -%d%%" % int(round(cd * 100.0)))
	var kh := ComboSystem.get_kill_heal()
	if kh > 0.0:
		parts.append("HP +%d" % int(kh))
	if not parts.is_empty():
		var line := "  ·  ".join(PackedStringArray(parts))
		draw_string_outline(ThemeDB.fallback_font, Vector2(2.0, 104.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, 4, Color(0.0, 0.0, 0.05, 0.85))
		draw_string(ThemeDB.fallback_font, Vector2(2.0, 104.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.95, 0.9, 0.7, alpha))
