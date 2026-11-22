class_name RelicData
extends Resource
## Một relic (vật phẩm đeo) bán ở Relic Merchant. Hiệu ứng cộng dồn khi sở hữu nhiều relic. Giá ≈ giá trị hiệu ứng (10% máu = 100 vàng).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var price: int = 100
## Merchant chỉ bán relic có tier <= số Boss đã hạ (tier 1 bán sau Boss 1, tier 2 sau Boss 2, tier 3 sau Boss 3).
@export_range(1, 3) var tier: int = 1
@export_group("Hiệu ứng")
@export_range(0.0, 1.0, 0.01) var max_hp_pct: float = 0.0
@export_range(0.0, 1.0, 0.01) var damage_pct: float = 0.0
## Giảm thời gian hồi chiêu (cộng với combo; tổng bị giới hạn ở PlayerStats.MAX_COOLDOWN_REDUCTION).
@export_range(0.0, 1.0, 0.01) var cooldown_pct: float = 0.0
@export_range(0.0, 1.0, 0.01) var move_speed_pct: float = 0.0
## Máu hồi mỗi khi hạ một Enemy.
@export var kill_heal: float = 0.0
## Tăng lượng vàng rơi (+% số đồng).
@export_range(0.0, 2.0, 0.01) var gold_pct: float = 0.0
## Cộng thêm vào tỉ lệ rơi viên máu (0.05 = +5 điểm phần trăm).
@export_range(0.0, 1.0, 0.01) var hp_drop_bonus: float = 0.0


## Danh sách dòng hiệu ứng để hiện trong bảng chi tiết (chỉ các chỉ số khác 0).
func get_effect_lines() -> Array[String]:
	var lines: Array[String] = []
	if max_hp_pct > 0.0:
		lines.append("+%d%% máu tối đa" % int(round(max_hp_pct * 100.0)))
	if damage_pct > 0.0:
		lines.append("+%d%% sát thương gây ra" % int(round(damage_pct * 100.0)))
	if cooldown_pct > 0.0:
		lines.append("-%d%% thời gian hồi chiêu" % int(round(cooldown_pct * 100.0)))
	if move_speed_pct > 0.0:
		lines.append("+%d%% tốc độ di chuyển" % int(round(move_speed_pct * 100.0)))
	if kill_heal > 0.0:
		lines.append("+%d máu mỗi lần hạ địch" % int(kill_heal))
	if gold_pct > 0.0:
		lines.append("+%d%% vàng rơi ra" % int(round(gold_pct * 100.0)))
	if hp_drop_bonus > 0.0:
		lines.append("+%d%% tỉ lệ rơi viên máu" % int(round(hp_drop_bonus * 100.0)))
	return lines
