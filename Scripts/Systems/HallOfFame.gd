extends Node
## Autoload "HallOfFame": CƠ SỞ DỮ LIỆU của game, lưu bằng JSON (Godot không có SQL sẵn; muốn dùng SQLite thật cần plugin godot-sqlite,
## khi đó chỉ cần thay phần đọc/ghi trong file này, các nơi khác gọi qua cùng các hàm).
##  - Bảng "runs"   : user://database/runs.json  -> mỗi lượt chơi đã kết thúc (tên, điểm, ngày giờ, thời gian sống sót, số lần dùng spell,
##                    tổng sát thương, số địch hạ gục, số relic đã mua, vàng đã kiếm, hạng combo cao nhất, hạ mấy Boss, có thắng game không).
##  - Danh mục tài nguyên: res://Data/game_data.json -> spell, relic, level, Boss lấy từ thư mục Resources (sinh bằng Tools/export_game_data.py),
##    dùng để hiện tên đẹp cho relic / level trong bảng.
## Hạng = sắp theo điểm giảm dần; bằng điểm thì ưu tiên người thắng game, rồi thời gian sống sót ngắn hơn.
## Lưu ý: không đặt class_name (tên HallOfFame dành cho Autoload).

signal runs_changed

const DB_DIR := "user://database/"
const RUNS_PATH := "user://database/runs.json"
const CATALOG_PATH := "res://Data/game_data.json"
const SCHEMA_VERSION: int = 1
const MAX_ROWS: int = 200

var _rows: Array[Dictionary] = []
var _next_id: int = 1
var _catalog: Dictionary = {}


func _ready() -> void:
	_load_catalog()
	_load_runs()


# ---------------------------------------------------------------- Bảng runs
## Ghi một lượt chơi; trả về {"id", "rank", "total"} (hạng bắt đầu từ 1).
func submit_run(entry: Dictionary) -> Dictionary:
	var row := entry.duplicate(true)
	row["id"] = _next_id
	_next_id += 1
	var now := Time.get_datetime_dict_from_system()
	row["finished_at"] = "%02d/%02d/%04d %02d:%02d" % [now["day"], now["month"], now["year"], now["hour"], now["minute"]]
	row["finished_unix"] = int(Time.get_unix_time_from_system())
	_rows.append(row)
	_sort_rows()
	if _rows.size() > MAX_ROWS:
		_rows.resize(MAX_ROWS)
	_save_runs()
	runs_changed.emit()
	return {"id": int(row["id"]), "rank": get_rank_of(int(row["id"])), "total": _rows.size()}


## Danh sách đã xếp hạng (hạng 1 ở đầu). limit <= 0 = lấy hết.
func get_top(limit: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := _rows.size() if limit <= 0 else mini(limit, _rows.size())
	for i in count:
		result.append(_rows[i])
	return result


func get_rank_of(run_id: int) -> int:
	for i in _rows.size():
		if int(_rows[i]["id"]) == run_id:
			return i + 1
	return -1


func get_row(run_id: int) -> Dictionary:
	for r in _rows:
		if int(r["id"]) == run_id:
			return r
	return {}


func get_count() -> int:
	return _rows.size()


func clear_runs() -> void:
	_rows.clear()
	_next_id = 1
	_save_runs()
	runs_changed.emit()


func _sort_rows() -> void:
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("score", 0))
		var sb := int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		var ca := bool(a.get("completed", false))
		var cb := bool(b.get("completed", false))
		if ca != cb:
			return ca
		return int(a.get("survival_sec", 0)) < int(b.get("survival_sec", 0)))


func _load_runs() -> void:
	_rows.clear()
	_next_id = 1
	if not FileAccess.file_exists(RUNS_PATH):
		return
	var file := FileAccess.open(RUNS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("HallOfFame: file runs.json hỏng, bỏ qua.")
		return
	var data: Dictionary = parsed
	for r in data.get("rows", []):
		if r is Dictionary:
			_rows.append(r)
	_next_id = maxi(int(data.get("next_id", 1)), 1)
	for r in _rows:
		_next_id = maxi(_next_id, int(r.get("id", 0)) + 1)
	_sort_rows()


func _save_runs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DB_DIR))
	var file := FileAccess.open(RUNS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("HallOfFame: không ghi được %s (lỗi %d)." % [RUNS_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"version": SCHEMA_VERSION, "next_id": _next_id, "rows": _rows}, "\t"))


# ---------------------------------------------------------------- Danh mục tài nguyên (JSON)
func _load_catalog() -> void:
	_catalog = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("HallOfFame: thiếu %s (chạy Tools/export_game_data.py để tạo). Tên relic / level sẽ hiện bằng id." % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_catalog = parsed


func catalog_name(table: String, id: String) -> String:
	var rows: Array = _catalog.get(table, [])
	for r in rows:
		if r is Dictionary and String(r.get("id", "")) == id:
			return String(r.get("name", id))
	return id


func catalog_table(table: String) -> Array:
	return _catalog.get(table, [])
