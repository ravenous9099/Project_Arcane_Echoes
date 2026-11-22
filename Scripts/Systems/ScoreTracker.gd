class_name ScoreTracker
extends Node
## Bảng điểm: cộng điểm mỗi khi Player hạ gục một Enemy (điểm lấy từ Enemy.score_value) và nhớ số lần hạ gục theo loại.
## Đạt score_goal điểm thì phát goal_reached một lần (Main dùng để mở cổng tới phòng Boss).
## Main tạo node này, gọi bind_spawner() một lần, và reset() khi bắt đầu lượt chơi mới.

signal score_changed(score: int, goal: int)
signal goal_reached
signal kill_recorded(enemy_name: String, points: int)

@export var score_goal: int = 200

var score: int = 0
var total_kills: int = 0
var goal_unlocked: bool = false
## Điểm lúc bắt đầu level hiện tại: thanh tiến độ tính từ mốc này tới score_goal (điểm cộng dồn qua các level).
var goal_base: int = 0

var _kills: Dictionary = {}  # tên Enemy -> {"count": số lần, "points": tổng điểm}


func bind_spawner(spawner: Node) -> void:
	if spawner != null and spawner.has_signal("enemy_spawned"):
		spawner.connect("enemy_spawned", _on_enemy_spawned)


func reset() -> void:
	goal_base = 0
	score = 0
	total_kills = 0
	goal_unlocked = false
	_kills.clear()
	score_changed.emit(score, score_goal)


## Bắt đầu level mới: GIỮ điểm hiện có, mục tiêu = điểm hiện tại + goal_points (cổng Boss khóa lại).
func begin_level(goal_points: int) -> void:
	goal_base = score
	score_goal = score + goal_points
	goal_unlocked = false
	score_changed.emit(score, score_goal)


## Cộng điểm cho một lần hạ gục (hoặc điểm thưởng/debug nếu enemy_name rỗng).
func add_points(points: int, enemy_name: String = "") -> void:
	score += points
	if not enemy_name.is_empty():
		total_kills += 1
		var entry: Dictionary = _kills.get(enemy_name, {"count": 0, "points": 0})
		entry["count"] = int(entry["count"]) + 1
		entry["points"] = int(entry["points"]) + points
		_kills[enemy_name] = entry
		kill_recorded.emit(enemy_name, points)
	score_changed.emit(score, score_goal)
	if not goal_unlocked and score >= score_goal:
		goal_unlocked = true
		goal_reached.emit()


## Tiến độ tới mục tiêu, 0..1.
func get_progress() -> float:
	return clampf(float(score - goal_base) / float(maxi(score_goal - goal_base, 1)), 0.0, 1.0)


## Danh sách hạ gục theo loại, loại nhiều điểm nhất ở trên: [{name, count, points}, ...].
func get_breakdown() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for enemy_name: String in _kills.keys():
		var entry: Dictionary = _kills[enemy_name]
		rows.append({"name": enemy_name, "count": int(entry["count"]), "points": int(entry["points"])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["points"]) > int(b["points"]))
	return rows


func _on_enemy_spawned(enemy: Node) -> void:
	if enemy != null and enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died)


func _on_enemy_died(enemy: Node) -> void:
	if not GameManager.is_run_active or enemy == null:
		return
	var points := int(enemy.get("score_value"))
	var enemy_name := String(enemy.get("enemy_name"))
	add_points(points, enemy_name if not enemy_name.is_empty() else "Enemy")
