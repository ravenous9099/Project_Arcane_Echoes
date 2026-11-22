class_name LevelConfig
extends Resource
## Dữ liệu của MỘT level (map + Enemy + điểm + Spell trên map + Boss). Thêm level mới = thêm một file .tres trong Resources/Levels/
## rồi thêm vào mảng `levels` của Main. Không cần sửa code.
## Các level chạy lần lượt theo thứ tự trong mảng; level có is_final = true là level cuối: hạ hết Boss thì kết thúc game (ending + Hall of Fame).

@export var id: StringName = &"level_1"
## Tên hiện trên banner và bảng điểm.
@export var display_name: String = "LEVEL 1"
## Mã giao diện map (xem MapTheme.create): "default" = bộ cây cỏ mặc định, "autumn" = gói Environment mùa thu.
@export var theme_id: StringName = &"default"

@export_group("Enemy")
## Các loại Enemy xuất hiện ở level này (chọn ngẫu nhiên đều nhau).
@export var enemy_scenes: Array[PackedScene] = []
## Tỉ lệ xuất hiện của từng loại, theo đúng thứ tự enemy_scenes (để trống = đều nhau). Số lớn hơn = xuất hiện nhiều hơn.
@export var enemy_weights: Array[float] = []
## Số lượng TỐI ĐA cùng lúc còn sống của từng loại, theo thứ tự enemy_scenes (-1 hoặc thiếu = không giới hạn).
## Ví dụ [-1, -1, 2] = Mage tối đa 2 con trên map.
@export var enemy_caps: Array[int] = []

@export_group("Điểm")
## Điểm cần THÊM (so với điểm lúc bước vào level) để mở cổng Boss. Điểm cộng dồn qua các level.
@export var goal_points: int = 500
## Điểm thưởng khi hạ Boss của level này (cộng vào điểm tổng, ảnh hưởng mục tiêu của level kế).
@export var boss_bonus_points: int = 0

@export_group("Spell trên map")
## Số Spell NGẪU NHIÊN lấy từ thư viện hiệu ứng (Resources/Spells/Library/) đặt thêm trên map mỗi level (chưa sở hữu). 0 = tắt.
@export var library_spells_on_map: int = 2
## Số viên Spell tối đa đặt trên map (chọn ngẫu nhiên trong số Spell chưa có). -1 = đặt hết số Spell còn lại.
@export var max_spells_on_map: int = -1

@export_group("Độ khó spawn")
@export var base_enemy_count: int = 3
@export var initial_spawn_count: int = 3
## Mỗi Spell đã thu thập cộng thêm bấy nhiêu Enemy mục tiêu.
@export var enemies_per_spell: float = 3.0
## Khi số Spell >= ngưỡng thì cộng thêm số Enemy tương ứng (cộng dồn). Hai mảng cùng độ dài.
@export var threshold_spell_counts: Array[int] = [2, 4]
@export var threshold_bonus_enemies: Array[int] = [2, 3]
@export var max_enemies: int = 30
@export var spawn_interval: float = 2.0
## > 0: kiểu sinh THEO ĐỢT. Mỗi đợt sinh ngẫu nhiên spawn_batch_min..max Enemy; đợt mới chỉ xuất hiện khi còn sống <= max_enemies - spawn_batch_max (không vượt max_enemies). 0 = sinh lẻ theo công thức độ khó.
@export var spawn_batch_min: int = 0
@export var spawn_batch_max: int = 0

@export_group("Boss")
## Scene Boss của level (có script Boss.gd hoặc lớp con).
@export var boss_scene: PackedScene
## Nếu KHÔNG rỗng: phòng Boss có nhiều Boss lần lượt xuất hiện (Boss kế xuất hiện sau khi hạ Boss trước), thay cho boss_scene.
@export var boss_sequence: Array[PackedScene] = []
## Cộng vào máu tối đa của mọi Boss ở level này (số âm = giảm; level 4: -500).
@export var boss_health_delta: float = 0.0
## Số viên máu mỗi Boss rơi ra khi chết (chỉ áp dụng cho phòng có nhiều Boss, chọn ngẫu nhiên trong khoảng).
@export var boss_drop_hearts_min: int = 3
@export var boss_drop_hearts_max: int = 5
## Level cuối: hạ Boss cuối cùng là thắng game (không có cổng thoát / sảnh nữa).
@export var is_final: bool = false
## Phần thưởng rơi ra khi hạ Boss (Ultimate ở level 1). Bỏ trống = không rơi gì. Đã sở hữu rồi thì không rơi nữa.
@export var reward_spell: SpellData


## Danh sách Boss của phòng Boss theo thứ tự xuất hiện.
func get_boss_scenes() -> Array[PackedScene]:
	if not boss_sequence.is_empty():
		return boss_sequence
	var single: Array[PackedScene] = []
	if boss_scene != null:
		single.append(boss_scene)
	return single
