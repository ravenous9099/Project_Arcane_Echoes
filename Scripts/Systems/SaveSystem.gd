extends Node
## Autoload "SaveSystem": lưu / đọc tiến trình ở sảnh chờ (user://savegame.json). Menu chính hiện nút "Tiếp tục" khi có file lưu.
## Nội dung lưu: level kế tiếp, vòng chơi, số Boss đã hạ, điểm, vàng, relic, spell đã có + ô trang bị + Ultimate.
## Máu, combo và vị trí không lưu (vào sảnh luôn đầy máu).

const SAVE_PATH := "user://savegame.json"
const SPELL_DIR := "res://Resources/Spells/"
## Thư viện spell hiệu ứng (Tools/generate_fx_spells.py): file tên = id.tres.
const LIBRARY_DIR := "res://Resources/Spells/Library/"
const VERSION := 1

## Menu chính đặt true khi bấm "Tiếp tục"; Main đọc và xoá cờ này khi nạp.
var continue_requested: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: không ghi được %s (lỗi %d)." % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_warning("SaveSystem: file lưu hỏng, bỏ qua.")
	return {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Tìm SpellData theo id trong Resources/Spells (kể cả Ultimate). null nếu không có.
func find_spell(id: StringName) -> SpellData:
	var library_path := LIBRARY_DIR + String(id) + ".tres"
	if ResourceLoader.exists(library_path):
		var from_library := load(library_path) as SpellData
		if from_library != null:
			return from_library
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		return null
	for f in dir.get_files():
		var file_name := f.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var spell := load(SPELL_DIR + file_name) as SpellData
		if spell != null and spell.id == id:
			return spell
	return null


# ---------------------------------------------------------------- Chụp / nạp trạng thái Spell
func capture_spells() -> Dictionary:
	var owned: Array[String] = []
	for s in SpellSystem.get_collected_spells():
		owned.append(String(s.id))
	var equipped: Array[String] = []
	for slot in SpellSystem.REGULAR_SLOT_COUNT:
		var eq := SpellSystem.get_equipped(slot)
		equipped.append(String(eq.id) if eq != null else "")
	var ult := SpellSystem.get_ultimate()
	return {"owned": owned, "equipped": equipped, "ultimate": String(ult.id) if ult != null else ""}


func apply_spells(data: Dictionary) -> void:
	SpellSystem.reset()
	for id in data.get("owned", []):
		var spell := find_spell(StringName(id))
		if spell != null:
			SpellSystem.collect_spell(spell)
	var equipped: Array = data.get("equipped", [])
	for slot in SpellSystem.REGULAR_SLOT_COUNT:
		SpellSystem.unequip(slot)
	for slot in mini(equipped.size(), SpellSystem.REGULAR_SLOT_COUNT):
		if String(equipped[slot]) != "":
			SpellSystem.equip(slot, StringName(equipped[slot]))
	var ult_id := String(data.get("ultimate", ""))
	if ult_id != "":
		var ult := find_spell(StringName(ult_id))
		if ult != null:
			SpellSystem.set_ultimate(ult)
