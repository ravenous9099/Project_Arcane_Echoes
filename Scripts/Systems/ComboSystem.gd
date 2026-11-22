extends Node
## Autoload "ComboSystem": bộ đếm combo hạng F -> D -> C -> B -> A -> S -> SS -> SSS.
## +1 điểm mỗi lần đánh trúng Enemy, +2 khi né hoàn hảo, bị thương thì tụt 1 hạng và mất hết điểm đang tích; mỗi 5 điểm lên 1 hạng; 2.5 giây không có điểm thì tụt 1 hạng.
## Buff theo hạng (sát thương, giảm hồi chiêu, hồi máu khi hạ Enemy) do PlayerStats cộng với relic. Thông số: Resources/combo_tuning.tres.
## Lưu ý: không đặt class_name (tên ComboSystem dành cho Autoload).

signal points_changed(points: int, rank: int)
signal rank_changed(rank: int, went_up: bool)

const RANK_NAMES: Array[String] = ["F", "D", "C", "B", "A", "S", "SS", "SSS"]
const RANK_COLORS: Array[Color] = [
	Color(0.62, 0.64, 0.7), Color(0.55, 0.85, 0.5), Color(0.35, 0.8, 1.0), Color(0.45, 0.6, 1.0),
	Color(1.0, 0.82, 0.3), Color(1.0, 0.55, 0.2), Color(1.0, 0.3, 0.35), Color(1.0, 0.35, 0.9),
]

var tuning: ComboTuning = ComboTuning.new()
var points: int = 0
var rank: int = 0
## Tổng số đòn đã đánh trúng Enemy kể từ lúc reset (hiện ở HUD).
var total_hits: int = 0
var _idle: float = 0.0


func _ready() -> void:
	if ResourceLoader.exists("res://Resources/combo_tuning.tres"):
		var loaded := load("res://Resources/combo_tuning.tres") as ComboTuning
		if loaded != null:
			tuning = loaded
	GameManager.run_started.connect(reset)


func _process(delta: float) -> void:
	if points <= 0 or not GameManager.is_run_active:
		return
	_idle += delta
	if _idle >= tuning.idle_decay_time:
		_idle = 0.0
		_set_points(points - tuning.points_per_rank)


func max_points() -> int:
	return (RANK_NAMES.size() - 1) * tuning.points_per_rank


func reset() -> void:
	total_hits = 0
	points = 0
	_idle = 0.0
	var old := rank
	rank = 0
	points_changed.emit(points, rank)
	if old != 0:
		rank_changed.emit(rank, false)


func add_points(amount: int) -> void:
	if amount <= 0:
		return
	_idle = 0.0
	_set_points(points + amount)


func remove_points(amount: int) -> void:
	_set_points(points - amount)


func _set_points(value: int) -> void:
	var new_points := clampi(value, 0, max_points())
	var old_rank := rank
	points = new_points
	rank = mini(points / maxi(tuning.points_per_rank, 1), RANK_NAMES.size() - 1)
	points_changed.emit(points, rank)
	if rank != old_rank:
		rank_changed.emit(rank, rank > old_rank)


## Tiến độ trong hạng hiện tại, 0..1 (hạng cao nhất = 1).
func get_rank_progress() -> float:
	if rank >= RANK_NAMES.size() - 1:
		return 1.0
	return float(points - rank * tuning.points_per_rank) / float(maxi(tuning.points_per_rank, 1))


## Tiến độ tới lần tụt hạng kế tiếp, 1 = vừa có điểm, 0 = sắp tụt.
func get_idle_ratio() -> float:
	if points <= 0:
		return 0.0
	return clampf(1.0 - _idle / maxf(tuning.idle_decay_time, 0.1), 0.0, 1.0)


func get_rank_name() -> String:
	return RANK_NAMES[rank]


func get_rank_color() -> Color:
	return RANK_COLORS[rank]


func get_damage_bonus() -> float:
	return tuning.damage_bonus[rank]


func get_cooldown_reduction() -> float:
	return tuning.cooldown_reduction[rank]


func get_kill_heal() -> float:
	return tuning.kill_heal[rank]


# ---------------------------------------------------------------- Móc nối từ gameplay
## Enemy gọi khi bị đòn của Player trúng.
func register_hit() -> void:
	total_hits += 1
	add_points(tuning.points_per_hit)


func register_perfect_dodge() -> void:
	add_points(tuning.points_per_perfect_dodge)


## Bị thương (bất kể bao nhiêu): tụt đúng 1 hạng và xoá điểm đang tích trong hạng (về đầu hạng mới). Đã ở hạng F thì chỉ xoá điểm.
func register_player_damaged() -> void:
	_idle = 0.0
	_set_points(maxi(rank - 1, 0) * tuning.points_per_rank)
