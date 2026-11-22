class_name SpellData
extends Resource
## Dữ liệu của MỘT loại Spell (chỉ là thông tin, không chứa logic).
## Mỗi Spell là một file .tres trong Resources/Spells/. Thêm Spell mới = tạo thêm 1 file .tres, không cần sửa code.
## Các trường mới (Cast, Sát thương, Đạn, Vùng nổ, Hình ảnh/Âm thanh) đều có giá trị mặc định,
## nên các file .tres cũ không khai báo chúng vẫn hoạt động.

## Cách spell hoạt động. PROJECTILE: bắn đạn theo hướng ngắm. AREA: nổ tại điểm ngắm (giới hạn bởi cast_range).
## RUSH: Player lao về phía con trỏ và đấm (dùng cho ô R, xem player.gd). Không đi qua SpellCaster.
## SHIELD: sóng chấn động quanh Player + hồi máu + bảo hộ bất tử ngắn (xem player.gd, nhóm "Sóng chấn động"). Không đi qua SpellCaster.
## SKILL: kỹ năng nhiều bước (danh sách `steps`): tích tụ -> thi triển -> đạn/nổ/vùng cháy nối tiếp nhau. Đi qua SpellCaster + SkillRunner.
## DASH: nâng cấp dash. Khi Player dash xong, `steps` chạy tại điểm đến / dọc đường lướt (xem player.gd). Bấm ô của nó = dash.
enum Kind { PROJECTILE, AREA, RUSH, SHIELD, SKILL, DASH }

## Mã định danh DUY NHẤT của Spell. Bộ đếm dựa vào mã này để không đếm trùng.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Màu đại diện (dùng cho viên Spell trên map, hình tạm của đạn/vùng nổ khi thiếu ảnh).
@export var color: Color = Color.WHITE
@export var icon: Texture2D
## Thời gian chờ giữa 2 lần dùng (giây), tính từ lúc spell được bắn.
@export var cooldown: float = 1.0
@export var damage: float = 10.0

@export_group("Thi triển")
@export var kind: Kind = Kind.PROJECTILE
## Thời gian chuẩn bị trước khi spell được bắn (giây). 0 = bắn ngay.
@export var cast_time: float = 0.1
## Thời gian hồi sau khi bắn, trong lúc này chưa thi triển được spell khác (giây).
@export var recovery_time: float = 0.15
## true: nhận sát thương trong lúc chuẩn bị thì bị ngắt.
@export var interruptible: bool = false
## Tầm tối đa của điểm ngắm (pixel) cho spell AREA. 0 = không giới hạn.
@export var cast_range: float = 0.0

@export_group("Sát thương")
## Thứ tự khớp với DamageInfo.Type.
@export_enum("Physical", "Fire", "Ice", "Arcane", "Dark") var damage_type: int = 0
## Lực đẩy lùi (pixel/giây). 0 = không đẩy.
@export var knockback_force: float = 0.0
## true: lực đẩy lùi bỏ qua knockback_resistance của mục tiêu (vẫn giảm còn một phần với Boss, xem Enemy.apply_forced_knockback).
@export var ignores_knockback_resistance: bool = false

@export_group("Hiệu ứng trạng thái (lên Player)")
## Choáng Player bấy nhiêu giây khi đòn trúng (0 = không). Chỉ có tác dụng khi người bắn là phe Enemy.
@export var stun_duration: float = 0.0
## Trói chân Player (không đi/lướt được nhưng vẫn dùng spell) bấy nhiêu giây khi đòn trúng (0 = không).
@export var root_duration: float = 0.0

@export_group("Sóng chấn động (SHIELD)")
## Bán kính ảnh hưởng (pixel). 128 = 4 ô của map (ô 32 px).
@export var shield_radius: float = 128.0
## Sát thương lên Enemy trong vùng (Enemy bị đẩy lùi).
@export var shield_damage: float = 20.0
@export var shield_knockback: float = 720.0
## Máu hồi cho Player khi dùng.
@export var shield_heal: float = 20.0
## Thời gian trường bảo hộ miễn nhiễm sát thương (giây).
@export var shield_duration: float = 2.5
## Boss trong vùng bị choáng bấy nhiêu giây (Boss không bị đẩy lùi nhiều, nên bị choáng thay thế).
@export var shield_boss_stun: float = 1.5

@export_group("Ô cố định / Ultimate")
## >= 0: Spell luôn nằm ở ô này (3 = phím R) và KHÔNG tính vào bộ đếm Spell (không làm tăng độ khó). -1 = Spell thường.
@export_range(-1, 3) var fixed_slot: int = -1
## Mana cần có đầy để dùng bản nâng cấp (Ultimate) của Spell này.
@export var mana_cost: float = 100.0

@export_group("Lao đấm (RUSH)")
## Quãng đường lao (pixel) và thời gian lao (giây) của bản thường.
@export var rush_distance: float = 80.0
@export var rush_duration: float = 0.14
## Cú đấm mạnh ở cuối bản thường (một vùng nổ AREA tức thì, đặt trước mặt Player).
@export var rush_punch: SpellData
## Khoảng cách từ tâm Player tới tâm cú đấm (pixel).
@export var punch_offset: float = 40.0
@export_subgroup("Bản nâng cấp (đủ mana)")
@export var ult_distance: float = 256.0
@export var ult_duration: float = 0.6
## Cú đấm liên tục trong lúc lao: số cú và vùng nổ của mỗi cú.
@export var ult_jab: SpellData
@export var ult_jab_count: int = 6
## Chấn động ở điểm cuối: sát thương + đẩy lùi mọi Enemy (kể cả Boss) trong vùng.
@export var ult_shockwave: SpellData
## Thời gian hồi sau khi dùng bản nâng cấp (giây).
@export var ult_cooldown: float = 2.0

@export_group("Đạn (PROJECTILE)")
@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 1.2
@export var projectile_radius: float = 8.0
## Số mục tiêu đạn xuyên qua thêm sau mục tiêu đầu tiên. 0 = dừng ở mục tiêu đầu.
@export var pierce: int = 0

@export_group("Vùng nổ (AREA)")
@export var area_radius: float = 64.0
## Thời gian báo trước (có vòng cảnh báo) trước khi gây sát thương (giây).
@export var area_delay: float = 0.0

@export_group("Hình ảnh và âm thanh")
## Thư mục chứa chuỗi ảnh PNG của đạn (PROJECTILE) hoặc của vùng nổ (AREA). Rỗng/không có ảnh = dùng hình tạm theo màu.
@export_dir var vfx_folder: String = ""
## Thư mục ảnh hiệu ứng khi đạn trúng mục tiêu hoặc vật cản (tùy chọn).
@export_dir var impact_vfx_folder: String = ""
## Tỉ lệ phóng ảnh. Chỉnh để khớp kích thước thật của ảnh.
@export var vfx_scale: float = 0.5
@export var vfx_fps: float = 24.0
## Xoay thêm cho ảnh (độ), dùng khi ảnh gốc không hướng sang phải.
@export var vfx_rotation_offset_deg: float = 0.0
## Âm thanh khi thi triển / khi trúng. Hiện để trống (project chưa có file âm thanh).
@export var cast_sound: AudioStream
@export var hit_sound: AudioStream

@export_group("Kỹ năng nhiều bước (SKILL / DASH)")
## Các bước chạy theo thời gian kể từ lúc spell được bắn (sau cast_time). Xem SkillStep.
@export var steps: Array[SkillStep] = []
## Hiệu ứng tích tụ năng lượng chạy trong cast_time (bám theo người thi triển). Rỗng = không có.
@export_dir var charge_vfx_folder: String = ""
@export var charge_vfx_scale: float = 2.0
@export var charge_vfx_fps: float = 12.0
## Khoảng cách từ người thi triển tới hiệu ứng tích tụ theo hướng ngắm (pixel).
@export var charge_offset: float = 16.0
@export_subgroup("Biểu tượng")
## Ảnh đại diện (signature) của kỹ năng ở ô kỹ năng: khung số icon_frame trong thư mục icon_folder.
## Không khai báo thì dùng icon, rồi tới khung giữa của vfx_folder.
@export_dir var icon_folder: String = ""
@export var icon_frame: int = 0
