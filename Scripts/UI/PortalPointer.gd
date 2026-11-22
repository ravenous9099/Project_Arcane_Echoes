class_name PortalPointer
extends Control
## Mũi tên chỉ hướng tới cổng Boss, vẽ quanh vị trí Player trên màn hình. Chỉ hiện khi cổng đã MỞ và còn ở xa.
## Dùng cho HUD: CombatHUD gán player và portal.

## Gần hơn mức này (pixel) thì ẩn mũi tên vì cổng đã nằm trong tầm nhìn.
const HIDE_DISTANCE: float = 380.0

var player: Node2D = null
var portal: BossPortal = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or portal == null or not is_instance_valid(player) or not is_instance_valid(portal) or not portal.unlocked:
		return
	var offset := portal.global_position - player.global_position
	var distance := offset.length()
	if distance < HIDE_DISTANCE:
		return
	var dir := offset / distance
	var side := Vector2(-dir.y, dir.x)
	# Vị trí Player trên màn hình (đã tính camera), rồi lùi ra một đoạn theo hướng cổng.
	var origin := player.get_global_transform_with_canvas().origin
	var tip := origin + dir * 96.0
	var back := tip - dir * 18.0
	var points := PackedVector2Array([tip, back + side * 10.0, back - side * 10.0])
	draw_colored_polygon(points, Color(1.0, 0.82, 0.3))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.85), 2.0)
	var text := "Cổng Boss  %d ô" % int(distance / 32.0)
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var text_pos := tip + dir * 18.0 - Vector2(text_size.x * 0.5, -4.0)
	draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.5))
