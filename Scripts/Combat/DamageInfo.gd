class_name DamageInfo
extends RefCounted
## Gói thông tin MỘT lần gây sát thương. Mọi nguồn sát thương (spell của Player, đạn của Enemy, va chạm...)
## đều tạo DamageInfo rồi gọi apply_to(mục tiêu), nên logic sát thương chỉ nằm ở take_damage() của mục tiêu.
## Mục tiêu (Player, Enemy) cần có: take_damage(amount: float, info: DamageInfo = null).
## Không tham chiếu tới SpellData bằng kiểu để tránh phụ thuộc vòng; trường spell chỉ là Resource.

## Loại sát thương. Thứ tự phải khớp với @export_enum của SpellData.damage_type.
enum Type { PHYSICAL, FIRE, ICE, ARCANE, DARK }

var amount: float = 0.0
var type: int = Type.PHYSICAL
## Ai gây ra sát thương (có thể null hoặc đã bị giải phóng, hãy kiểm tra is_instance_valid trước khi dùng).
var source: Node = null
## Vector đẩy lùi (hướng * lực, pixel/giây). ZERO = không đẩy.
var knockback: Vector2 = Vector2.ZERO
## Spell tạo ra sát thương này (nếu có), dùng cho hiệu ứng/âm thanh sau này.
var spell: Resource = null
## true: đẩy lùi cả mục tiêu có knockback_resistance cao (Boss) - dùng cho sóng xung kích của Ultimate.
var force_knockback: bool = false
## Hiệu ứng trạng thái lên Player nếu đòn này THỰC SỰ gây sát thương (giây). 0 = không có.
## stun_time: choáng (không di chuyển, không dùng spell, không lướt). root_time: trói chân (không di chuyển/lướt, vẫn dùng spell).
var stun_time: float = 0.0
var root_time: float = 0.0


static func create(p_amount: float, p_type: int = Type.PHYSICAL, p_source: Node = null, p_knockback: Vector2 = Vector2.ZERO, p_spell: Resource = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.type = p_type
	info.source = p_source
	info.knockback = p_knockback
	info.spell = p_spell
	return info


## Gây sát thương lên target. Trả về false nếu target không hợp lệ hoặc không có take_damage().
func apply_to(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return false
	target.take_damage(amount, self)
	return true
