class_name CombatFx
extends RefCounted
## Điểm móc (hook) chung cho hiệu ứng và âm thanh chiến đấu, để spell/đạn không tự dựng node lặp lại.
## Âm thanh: hiện chưa có file âm thanh nào trong project, stream = null thì không làm gì.


## Màu số sát thương theo loại (thứ tự khớp DamageInfo.Type: PHYSICAL, FIRE, ICE, ARCANE, DARK).
const DAMAGE_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.6, 0.2),
	Color(0.5, 0.85, 1.0),
	Color(1.0, 0.9, 0.3),
	Color(0.78, 0.5, 1.0),
]
## Số sát thương Player phải chịu luôn màu đỏ để phân biệt với sát thương Player gây ra.
const PLAYER_HIT_COLOR := Color(1.0, 0.35, 0.35)


## Hiện số sát thương bay lên tại world_pos. Đặt vào parent (thường là node Entities cùng cha với nạn nhân).
## Số càng lớn thì chữ càng to (tối đa khi sát thương >= 20).
static func spawn_damage_number(parent: Node, world_pos: Vector2, amount: float, damage_type: int = 0, on_player: bool = false) -> void:
	if not CombatTuning.current().damage_numbers_enabled or parent == null or not is_instance_valid(parent) or amount < 0.5:
		return
	var color := PLAYER_HIT_COLOR if on_player else DAMAGE_COLORS[clampi(damage_type, 0, DAMAGE_COLORS.size() - 1)]
	var font_size := 14 + int(clampf(amount / 20.0, 0.0, 1.0) * 10.0)
	var number := FloatingText.new()
	number.setup(str(roundi(amount)), color, font_size)
	parent.add_child(number)
	number.global_position = world_pos + Vector2(randf_range(-8.0, 8.0), 0.0)


## Hiện một dòng chữ nổi (ví dụ "NÉ HOÀN HẢO") bay lên tại world_pos.
static func spawn_text(parent: Node, world_pos: Vector2, text: String, color: Color, font_size: int = 16, life: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var label := FloatingText.new()
	label.setup(text, color, font_size, life, 42.0)
	parent.add_child(label)
	label.global_position = world_pos


static func play_sound_at(parent: Node, stream: AudioStream, pos: Vector2) -> void:
	if stream == null or parent == null or not is_instance_valid(parent):
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	parent.add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()


## Tạo hiệu ứng một lần tại pos. folder rỗng hoặc không có ảnh thì dùng hình tạm theo màu.
static func spawn_impact(parent: Node, folder: String, pos: Vector2, color: Color, sprite_scale: float, fps: float, fallback_radius: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var fx := OneShotVfx.new()
	fx.setup(folder, color, sprite_scale, fps, fallback_radius)
	parent.add_child(fx)
	fx.global_position = pos
