extends Node
## Autoload "RelicSystem": danh mục relic (Resources/Relics/*.tres), relic đang sở hữu, mua / bán và số Boss đã hạ (quyết định hàng Merchant bán).
## Giá bán lại = sell_ratio * giá gốc. Hiệu ứng được PlayerStats cộng dồn.

signal relics_changed
signal bosses_defeated_changed(count: int)

const RELIC_DIR := "res://Resources/Relics/"
const SELL_RATIO: float = 0.5
const MAX_OWNED: int = 7

var bosses_defeated: int = 0
var _catalog: Array[RelicData] = []
var _owned: Array[StringName] = []


func _ready() -> void:
	_load_catalog()


func _load_catalog() -> void:
	_catalog.clear()
	var dir := DirAccess.open(RELIC_DIR)
	if dir == null:
		push_warning("RelicSystem: không mở được %s" % RELIC_DIR)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		var file_name := f.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var relic := load(RELIC_DIR + file_name) as RelicData
		if relic != null and relic.id != &"":
			_catalog.append(relic)
	_catalog.sort_custom(func(a: RelicData, b: RelicData) -> bool: return a.tier < b.tier or (a.tier == b.tier and a.price < b.price))


func get_catalog() -> Array[RelicData]:
	return _catalog


func get_relic(id: StringName) -> RelicData:
	for r in _catalog:
		if r.id == id:
			return r
	return null


func get_owned() -> Array[RelicData]:
	var result: Array[RelicData] = []
	for id in _owned:
		var r := get_relic(id)
		if r != null:
			result.append(r)
	return result


func get_owned_ids() -> Array[StringName]:
	return _owned.duplicate()


func owns(id: StringName) -> bool:
	return _owned.has(id)


## Hàng Merchant đang bán: relic đã mở khoá theo số Boss đã hạ và chưa sở hữu.
func get_stock() -> Array[RelicData]:
	var result: Array[RelicData] = []
	for r in _catalog:
		if r.tier <= bosses_defeated and not _owned.has(r.id):
			result.append(r)
	return result


func get_sell_price(relic: RelicData) -> int:
	return int(round(float(relic.price) * SELL_RATIO))


## Trả về "" nếu mua được, ngược lại là lý do (hiện cho người chơi).
func try_buy(relic: RelicData) -> String:
	if relic == null or _owned.has(relic.id):
		return "Bạn đã có relic này."
	if _owned.size() >= MAX_OWNED:
		return "Túi relic đã đầy (%d)." % MAX_OWNED
	if not Wallet.spend(relic.price):
		return "Không đủ vàng."
	_owned.append(relic.id)
	RunStats.relics_bought += 1
	relics_changed.emit()
	return ""


func sell(relic: RelicData) -> bool:
	if relic == null or not _owned.has(relic.id):
		return false
	_owned.erase(relic.id)
	Wallet.add(get_sell_price(relic), false)
	relics_changed.emit()
	return true


func register_boss_defeated() -> void:
	bosses_defeated += 1
	bosses_defeated_changed.emit(bosses_defeated)


func reset() -> void:
	_owned.clear()
	bosses_defeated = 0
	relics_changed.emit()
	bosses_defeated_changed.emit(bosses_defeated)


func load_state(owned_ids: Array, boss_count: int) -> void:
	_owned.clear()
	for id in owned_ids:
		if get_relic(StringName(id)) != null:
			_owned.append(StringName(id))
	bosses_defeated = boss_count
	relics_changed.emit()
	bosses_defeated_changed.emit(bosses_defeated)


# ---------------------------------------------------------------- Tổng hiệu ứng
func sum_stat(property: StringName) -> float:
	var total := 0.0
	for r in get_owned():
		total += float(r.get(property))
	return total
