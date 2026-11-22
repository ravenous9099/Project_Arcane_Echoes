class_name SkillStep
extends Resource
## MỘT bước của kỹ năng nhiều bước (SpellData.kind = SKILL hoặc DASH). Kỹ năng = danh sách bước chạy theo thời gian:
## hiệu ứng hình (VFX), nổ gây sát thương tức thì (BURST), đạn bay (PROJECTILE) và vùng cháy kéo dài (ZONE).
## Đạn có thể rải "vệt" (trail) phía sau và kích hoạt các bước nối tiếp (on_end) tại điểm kết thúc -> tạo chuỗi hiệu ứng.
## Toàn bộ chỉ là dữ liệu (.tres), thêm kỹ năng mới không cần sửa code.

enum Type { VFX, BURST, PROJECTILE, ZONE }
## Vị trí bước xuất hiện (chỉ dùng cho bước cấp cao nhất của kỹ năng; bước trong on_end/trail xuất hiện tại điểm của đạn).
## CASTER: tại người thi triển. FRONT: cách người thi triển `offset` pixel theo hướng ngắm.
## AIM: tại con trỏ (giới hạn bởi max_range nếu > 0). PATH: rải dọc đường dash, cách nhau path_spacing (chỉ cho kỹ năng DASH).
enum Anchor { CASTER, FRONT, AIM, PATH }

@export var type: Type = Type.VFX
## Thời điểm chạy, tính từ lúc kỹ năng được thi triển (giây). Với bước trong on_end/trail: trễ sau khi đạn kết thúc/rải vệt.
@export var delay: float = 0.0
@export var anchor: Anchor = Anchor.FRONT
@export var offset: float = 0.0
@export var path_spacing: float = 28.0
## Dời thêm vị trí xuất hiện (thế giới, pixel) sau khi đã tính anchor. Dùng để rải cụm nổ/đặt ảnh lệch khỏi tâm.
@export var pos_offset: Vector2 = Vector2.ZERO

@export_group("Hình ảnh")
## Thư mục chuỗi ảnh (ví dụ res://Assets/Spell/Effect Bullet Impact Explosion 32x32/Sliced/Red/d04).
@export_dir var vfx_folder: String = ""
@export var vfx_scale: float = 2.0
@export var vfx_fps: float = 16.0
## VFX/ZONE: > 0 thì hiệu ứng tồn tại đúng chừng này giây (phát một lần được kéo giãn cho vừa; lặp thì lặp tới hết giờ).
@export var duration: float = 0.0
## true: lặp ảnh trong suốt thời gian duration. false: phát một lần.
@export var vfx_loop: bool = false
## true: xoay ảnh theo hướng ngắm / hướng bay.
@export var rotate_to_dir: bool = false
@export var vfx_rotation_offset_deg: float = 0.0
@export var color: Color = Color.WHITE

@export_group("Sát thương (BURST / ZONE / chạm của PROJECTILE)")
@export var damage: float = 0.0
@export_enum("Physical", "Fire", "Ice", "Arcane", "Dark") var damage_type: int = 0
@export var radius: float = 40.0
## Lực đẩy lùi (pixel/giây) đẩy ra xa tâm nổ. 340 ≈ 2 ô.
@export var knockback_force: float = 0.0
## ZONE: khoảng cách giữa các lần gây sát thương lên cùng một mục tiêu (giây).
@export var tick_interval: float = 0.5

@export_group("Đạn (PROJECTILE)")
@export var count: int = 1
## Tổng góc quạt (độ) khi count > 1.
@export var spread_deg: float = 0.0
@export var speed: float = 300.0
## Quãng bay tối đa (pixel). 8 ô = 256.
@export var max_range: float = 256.0
## true: dừng tại điểm con trỏ nếu gần hơn max_range.
@export var stop_at_aim: bool = false
@export var contact_radius: float = 10.0
## Số mục tiêu đạn xuyên qua thêm sau mục tiêu đầu (mỗi mục tiêu nhận damage khi chạm một lần). 0 = dừng ở mục tiêu đầu.
@export var pierce: int = 0
## Tốc độ quay ảnh của đạn (độ/giây), dùng cho đá lăn.
@export var spin_deg_per_sec: float = 0.0
## Rải bước này (thường là ZONE vệt lửa) sau đạn, cách nhau trail_spacing pixel.
@export var trail: SkillStep
@export var trail_spacing: float = 24.0
## Chạy tại điểm kết thúc của đạn (trúng mục tiêu, trúng vật cản hoặc hết tầm).
@export var on_end: Array[SkillStep] = []
