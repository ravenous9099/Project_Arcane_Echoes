extends Node
## Autoload "SpellSystem": theo dõi Spell người chơi ĐÃ THU THẬP và Spell ĐANG TRANG BỊ.
## - Độ khó (EnemySpawner) chỉ dựa vào get_collected_count().
## - Mỗi Spell (theo id) chỉ được tính 1 lần: nhặt trùng, signal bị gọi trùng, đổi/tháo trang bị đều KHÔNG làm đếm tăng.
## Lưu ý: không đặt class_name cho script này, vì tên SpellSystem đã dành cho Autoload.

## Phát ra khi nhặt được Spell MỚI. total_collected là số Spell đã thu thập sau khi nhặt.
signal spell_collected(spell: SpellData, total_collected: int)
signal spell_equipped(slot: int, spell: SpellData)
signal spell_unequipped(slot: int)
## Phát ra khi bắt đầu lượt chơi mới và xóa sạch dữ liệu.
signal collection_reset
## Phát ra khi một Spell bắt đầu hồi chiêu (HUD dùng để vẽ lớp phủ cooldown).
signal spell_cooldown_started(spell: SpellData, duration: float)
## Nhặt được Ultimate (ô R). KHÔNG đi qua spell_collected, nên không làm tăng độ khó.
signal ultimate_acquired(spell: SpellData)
## Nhặt Spell thường khi 3 ô thường đã đầy: người chơi cần chọn ô để thay (Main hiện hướng dẫn).
signal replacement_needed(spell: SpellData)
signal replacement_resolved
## Nhặt Spell thường nhưng 3 ô đã đầy: Spell nằm trong kho (Tab để trang bị).
signal spell_stored(spell: SpellData)
## Kho hoặc ô trang bị đổi (InventoryPanel vẽ lại).
signal inventory_changed

## Số ô trang bị, ứng với các phím spell_1 ... spell_4 trong Input Map.
const SLOT_COUNT: int = 4
## Ô cuối (phím R) dành riêng cho Ultimate; Spell thường chỉ dùng các ô 0..2 (chuột, Q, E).
const ULTIMATE_SLOT: int = 3
const REGULAR_SLOT_COUNT: int = 3

var _collected: Dictionary = {}  # id (StringName) -> SpellData
var _equipped: Array[SpellData] = []
## Cooldown theo id Spell (không theo ô): đổi ô không làm mất/gian lận cooldown.
var _cooldown_left: Dictionary = {}  # id (StringName) -> giây còn lại
var _cooldown_total: Dictionary = {}  # id (StringName) -> tổng thời gian cooldown lần gần nhất
var _ultimate: SpellData = null
## Spell thường vừa nhặt nhưng chưa có ô trống (đang chờ người chơi chọn ô thay thế).
var pending_spell: SpellData = null


func _ready() -> void:
	_equipped.resize(SLOT_COUNT)


# ---------------------------------------------------------------- Thu thập
## Gọi khi người chơi nhặt Spell. Trả về true nếu đây là Spell MỚI (bộ đếm tăng), false nếu đã có.
func collect_spell(spell: SpellData) -> bool:
	if spell == null or spell.id == &"":
		push_warning("SpellSystem: Spell không hợp lệ (null hoặc thiếu id).")
		return false
	if spell.fixed_slot >= 0:
		return set_ultimate(spell)  # Spell ô cố định (Ultimate): không tính vào bộ đếm
	if _collected.has(spell.id):
		return false
	_collected[spell.id] = spell
	spell_collected.emit(spell, _collected.size())
	_auto_equip(spell)  # tự trang bị vào ô trống đầu tiên (không ảnh hưởng bộ đếm)
	return true


func has_spell(id: StringName) -> bool:
	return _collected.has(id) or (_ultimate != null and _ultimate.id == id)


## Đặt Ultimate vào ô R. Trả về false nếu đã có. Không đổi bộ đếm Spell.
func set_ultimate(spell: SpellData) -> bool:
	if spell == null or _ultimate != null:
		return false
	_ultimate = spell
	_equipped[ULTIMATE_SLOT] = spell
	spell_equipped.emit(ULTIMATE_SLOT, spell)
	ultimate_acquired.emit(spell)
	return true


func has_ultimate() -> bool:
	return _ultimate != null


func get_ultimate() -> SpellData:
	return _ultimate


## Thay Spell ở ô thường bằng Spell đang chờ (pending_spell). Trả về false nếu không có Spell chờ hoặc ô không hợp lệ.
func resolve_replacement(slot: int) -> bool:
	if pending_spell == null or slot < 0 or slot >= REGULAR_SLOT_COUNT:
		return false
	_equipped[slot] = pending_spell
	pending_spell = null
	spell_equipped.emit(slot, _equipped[slot])
	replacement_resolved.emit()
	return true


## Bỏ qua Spell đang chờ (vẫn được tính là đã thu thập).
func cancel_replacement() -> void:
	if pending_spell != null:
		pending_spell = null
		replacement_resolved.emit()


func get_collected_count() -> int:
	return _collected.size()


func get_collected_spells() -> Array[SpellData]:
	var result: Array[SpellData] = []
	for s in _collected.values():
		result.append(s)
	return result


# ---------------------------------------------------------------- Trang bị
## Trang bị Spell đã thu thập vào ô slot (0..3). Không làm đổi bộ đếm.
func equip(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= REGULAR_SLOT_COUNT or not _collected.has(id):
		return false
	_equipped[slot] = _collected[id]
	spell_equipped.emit(slot, _equipped[slot])
	inventory_changed.emit()
	return true


## Đổi chỗ hai ô trang bị (dùng khi người chơi sắp xếp lại hotbar).
func swap_slots(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_a >= REGULAR_SLOT_COUNT or slot_b < 0 or slot_b >= REGULAR_SLOT_COUNT or slot_a == slot_b:
		return false
	var tmp := _equipped[slot_a]
	_equipped[slot_a] = _equipped[slot_b]
	_equipped[slot_b] = tmp
	for slot in [slot_a, slot_b]:
		if _equipped[slot] != null:
			spell_equipped.emit(slot, _equipped[slot])
		else:
			spell_unequipped.emit(slot)
	return true


func unequip(slot: int) -> void:
	if slot < 0 or slot >= REGULAR_SLOT_COUNT or _equipped[slot] == null:
		return
	_equipped[slot] = null
	spell_unequipped.emit(slot)
	inventory_changed.emit()


func get_equipped(slot: int) -> SpellData:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	return _equipped[slot]


func get_equipped_count() -> int:
	var n := 0
	for s in _equipped:
		if s != null:
			n += 1
	return n


## Ô thường (0..2) đang giữ Spell có mã id, -1 nếu không ở ô nào.
func get_slot_of(id: StringName) -> int:
	for slot in REGULAR_SLOT_COUNT:
		if _equipped[slot] != null and _equipped[slot].id == id:
			return slot
	return -1


## Kéo Spell từ kho vào ô slot: nếu Spell đang ở ô khác thì ĐỔI CHỖ hai ô, nếu không thì thay Spell cũ của ô đó (Spell cũ về kho).
func assign_to_slot(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= REGULAR_SLOT_COUNT or not _collected.has(id):
		return false
	var current := get_slot_of(id)
	if current == slot:
		return true
	if current >= 0:
		swap_slots(current, slot)
	else:
		equip(slot, id)
	inventory_changed.emit()
	return true


# ---------------------------------------------------------------- Cooldown
## Bắt đầu hồi chiêu cho Spell (thời gian lấy từ SpellData.cooldown). Gọi khi Spell thực sự được bắn.
func start_cooldown(spell: SpellData, duration: float = -1.0) -> void:
	var total := spell.cooldown if (spell != null and duration < 0.0) else duration
	if spell == null or spell.id == &"" or total <= 0.0:
		return
	total *= PlayerStats.cooldown_multiplier()  # buff combo + relic giảm hồi chiêu
	_cooldown_left[spell.id] = total
	_cooldown_total[spell.id] = total
	spell_cooldown_started.emit(spell, total)


## Xóa hồi chiêu của Spell (Ultimate sẵn sàng ngay khi mana đầy).
func reset_cooldown(spell: SpellData) -> void:
	if spell == null:
		return
	_cooldown_left.erase(spell.id)
	_cooldown_total.erase(spell.id)


func is_ready(spell: SpellData) -> bool:
	return spell != null and get_cooldown_remaining(spell) <= 0.0


func get_cooldown_remaining(spell: SpellData) -> float:
	if spell == null:
		return 0.0
	return float(_cooldown_left.get(spell.id, 0.0))


## 0 = sẵn sàng, 1 = vừa bắt đầu hồi (dùng cho lớp phủ cooldown của HUD).
func get_cooldown_ratio(spell: SpellData) -> float:
	if spell == null:
		return 0.0
	var total := float(_cooldown_total.get(spell.id, 0.0))
	if total <= 0.0:
		return 0.0
	return clampf(get_cooldown_remaining(spell) / total, 0.0, 1.0)


# Autoload này không ở chế độ ALWAYS nên cooldown tự dừng khi game tạm dừng.
func _process(delta: float) -> void:
	if _cooldown_left.is_empty():
		return
	for id in _cooldown_left.keys():
		var left: float = _cooldown_left[id] - delta
		if left <= 0.0:
			_cooldown_left.erase(id)
		else:
			_cooldown_left[id] = left


# ---------------------------------------------------------------- Lượt chơi mới
func reset() -> void:
	_collected.clear()
	_ultimate = null
	pending_spell = null
	_equipped.fill(null)
	_cooldown_left.clear()
	_cooldown_total.clear()
	collection_reset.emit()
	inventory_changed.emit()


func _auto_equip(spell: SpellData) -> void:
	for slot in REGULAR_SLOT_COUNT:
		if _equipped[slot] == null:
			equip(slot, spell.id)
			return
	# Ba ô thường đã đầy: Spell nằm trong kho, người chơi mở Tab để kéo vào ô muốn dùng (không tự ý đè Spell đang dùng).
	spell_stored.emit(spell)
	inventory_changed.emit()
