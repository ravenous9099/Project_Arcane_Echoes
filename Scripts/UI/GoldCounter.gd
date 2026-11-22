class_name GoldCounter
extends Control
## Số vàng đang có (góc dưới phải): đồng xu + con số; số nảy lên mỗi khi nhặt thêm. Dữ liệu từ autoload Wallet.

var _shown: float = 0.0
var _pop: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(150.0, 36.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_shown = float(Wallet.gold)
	Wallet.gold_changed.connect(func(_g: int, delta: int) -> void:
		if delta > 0:
			_pop = 1.0)


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 4.0, 0.0)
	_shown = move_toward(_shown, float(Wallet.gold), maxf(80.0 * delta, absf(float(Wallet.gold) - _shown) * 8.0 * delta))
	queue_redraw()


func _draw() -> void:
	draw_style_box(UIStyle.box(12, Color(0.04, 0.04, 0.08, 0.75), Color(1.0, 0.82, 0.3, 0.6), 2), Rect2(Vector2.ZERO, size))
	var c := Vector2(20.0, size.y * 0.5)
	draw_circle(c, 10.0, Color(0.55, 0.38, 0.05))
	draw_circle(c, 8.5, Color(1.0, 0.8, 0.2))
	draw_circle(c + Vector2(-2.0, -2.0), 3.5, Color(1.0, 0.95, 0.6))
	var fs := 20 + int(6.0 * _pop)
	draw_string(ThemeDB.fallback_font, Vector2(38.0, size.y * 0.5 + 7.0), str(int(round(_shown))), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(1.0, 0.92, 0.55).lerp(Color.WHITE, _pop))
