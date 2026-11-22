class_name CombatTuning
extends Resource
## MỌI thông số "cảm giác chiến đấu" và cân bằng chung nằm ở đây, thay cho các con số rải rác trong nhiều script.
## Chỉnh trong Inspector: mở Resources/combat_tuning.tres. Main nạp file này lúc khởi động và đăng ký bằng CombatTuning.set_current().
## Các hệ thống khác chỉ đọc qua CombatTuning.current() nên không cần tham chiếu trực tiếp tới Main.
## Một số giá trị (rung màn hình, hitstop, âm lượng, số sát thương) còn được người chơi chỉnh trong menu tạm dừng và lưu lại (GameSettings).

static var _current: CombatTuning = null


static func current() -> CombatTuning:
	if _current == null:
		_current = CombatTuning.new()
	return _current


static func set_current(tuning: CombatTuning) -> void:
	_current = tuning if tuning != null else CombatTuning.new()


@export_group("Hitstop (khựng khung hình khi trúng đòn)")
@export var hitstop_enabled: bool = true
## Tốc độ game trong lúc khựng (0.05 = gần như đứng yên).
@export_range(0.01, 1.0, 0.01) var hitstop_time_scale: float = 0.05
@export var hitstop_light: float = 0.03
@export var hitstop_heavy: float = 0.055
@export var hitstop_kill: float = 0.085
@export var hitstop_player_hurt: float = 0.07
@export var hitstop_boss_event: float = 0.16
## Một đòn từ mức sát thương này trở lên được coi là "nặng".
@export var heavy_hit_damage: float = 25.0

@export_group("Rung màn hình")
## Nhân cường độ toàn bộ các cú rung. 0 = tắt hẳn. Người chơi chỉnh trong menu tạm dừng.
@export_range(0.0, 2.0, 0.05) var shake_multiplier: float = 1.0
@export var shake_hit: float = 1.5
@export var shake_heavy_hit: float = 3.0
@export var shake_kill: float = 3.5
@export var shake_player_hurt: float = 5.0
@export var shake_duration: float = 0.18

@export_group("Âm thanh")
@export var sfx_enabled: bool = true
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = -8.0
@export var music_enabled: bool = true
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -12.0

@export_group("Hiển thị")
@export var damage_numbers_enabled: bool = true

@export_group("Đẩy lùi")
## Nhân lực đẩy lùi của mọi đòn (cả Player và Enemy).
@export_range(0.0, 2.0, 0.05) var knockback_multiplier: float = 1.0

@export_group("Enemy thường")
@export_range(0.2, 3.0, 0.05) var enemy_health_multiplier: float = 1.0
@export_range(0.2, 3.0, 0.05) var enemy_damage_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.05) var enemy_speed_multiplier: float = 1.0
## Thời gian báo trước tối thiểu của MỌI đòn Enemy (giây), để đòn luôn đọc được dù chỉnh số ở đâu.
@export var min_telegraph_time: float = 0.45

@export_group("Player")
## Nhân sát thương mọi Spell của Player.
@export_range(0.2, 3.0, 0.05) var player_damage_multiplier: float = 1.0
## Bấm spell hơi sớm (đang hồi/đang cast) trong khoảng này (giây) vẫn được nhớ và bắn ngay khi được.
@export var spell_buffer_time: float = 0.12
## Sau khi lướt xong, Player "khựng" bấy nhiêu giây: chậm lại và không bắn được (cái giá của việc lướt).
@export var dash_end_lag: float = 0.08

@export_group("Viên máu (rơi khi hạ Enemy)")
## Xác suất rơi một viên máu khi Player hạ gục Enemy thường (0..1). Boss không rơi.
@export_range(0.0, 1.0, 0.01) var hp_drop_chance: float = 0.12
## Máu hồi khi nhặt.
@export var hp_drop_heal: float = 20.0
## Viên máu tự biến mất sau bấy nhiêu giây nếu không nhặt (0 = không biến mất).
@export var hp_drop_lifetime: float = 25.0

@export_group("Vàng")
## Xác suất Enemy thường rơi vàng khi bị hạ.
@export_range(0.0, 1.0, 0.01) var gold_drop_chance: float = 0.30
@export var gold_drop_min: int = 3
@export var gold_drop_max: int = 7
## Boss luôn rơi vàng trong khoảng này.
@export var boss_gold_min: int = 100
@export var boss_gold_max: int = 120
## Đồng vàng bay về phía Player khi lại gần hơn khoảng này (pixel).
@export var gold_magnet_range: float = 110.0
@export var gold_lifetime: float = 30.0

@export_group("Mana / Ultimate")
@export var mana_max: float = 100.0
## Mana nhận được khi đánh trúng một Enemy.
@export var mana_per_hit: float = 5.0
## Mana nhận được khi hạ gục một Enemy (thay vì, không cộng dồn với mana đánh trúng của đòn đó).
@export var mana_per_kill: float = 10.0
## Mana tụt mỗi giây khi chưa đầy (đầy rồi thì giữ nguyên cho tới khi dùng Ultimate).
@export var mana_decay_per_second: float = 6.0
## Sau mỗi lần nhận mana, chờ bấy nhiêu giây rồi mới bắt đầu tụt.
@export var mana_decay_delay: float = 1.0

@export_group("Né hoàn hảo (dash)")
## Lướt đúng lúc để đòn trúng vào khung bất tử thì được thưởng.
@export var perfect_dodge_enabled: bool = true
## Thưởng: hoàn lại một lượt lướt.
@export var perfect_dodge_refund_dash: bool = true
@export_range(0.1, 1.0, 0.05) var perfect_dodge_slowmo_scale: float = 0.4
@export var perfect_dodge_slowmo_time: float = 0.25
## Giãn cách tối thiểu giữa 2 lần thưởng (giây), chống lạm dụng.
@export var perfect_dodge_cooldown: float = 0.8
## Đòn nhẹ hơn mức này không tính là "né hoàn hảo".
@export var perfect_dodge_min_damage: float = 5.0

@export_group("Boss")
@export_range(0.2, 3.0, 0.05) var boss_health_multiplier: float = 1.0
@export_range(0.2, 3.0, 0.05) var boss_damage_multiplier: float = 1.0
## > 1 = Boss nghỉ ít hơn (nhịp nhanh hơn); < 1 = chậm hơn.
@export_range(0.5, 2.0, 0.05) var boss_pace_multiplier: float = 1.0
## Boss học hành vi người chơi (đổi tỉ lệ chọn đòn, ngắm đón đầu, nhử lướt).
@export var boss_learning_enabled: bool = true
## 0 = không thích nghi, 1 = bình thường, 2 = rất mạnh.
@export_range(0.0, 2.0, 0.1) var boss_learning_strength: float = 1.0
## Áp lực tối đa: Boss nghỉ ít hơn tới mức này khi Player không bị trúng đòn lâu.
@export_range(1.0, 2.0, 0.05) var boss_pressure_max: float = 1.35
## Xác suất nối đòn liền (không nghỉ) sau khi hồi xong.
@export_range(0.0, 1.0, 0.05) var boss_combo_chance_phase1: float = 0.3
@export_range(0.0, 1.0, 0.05) var boss_combo_chance_phase2: float = 0.5
