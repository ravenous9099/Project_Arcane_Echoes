class_name ManaPool
extends Node
## Thanh mana của Ultimate (ô R). Chỉ "tồn tại" với người chơi sau khi nhặt Ultimate (unlock()).
## Quy tắc:
##  - Bắt đầu ở 0. Đánh trúng Enemy +mana_per_hit, hạ gục +mana_per_kill (xem CombatTuning).
##  - Chưa đầy: mana TỤT liên tục (sau mana_decay_delay giây không nhận thêm). Phải đánh liên tục mới đầy được.
##  - Đầy rồi: ngừng tụt, phát became_full (Main/Player reset hồi chiêu R). Dùng Ultimate -> consume() về 0.
## Là con của Player (Player tạo bằng code). Mọi con số nằm trong CombatTuning.

signal changed(value: float, max_value: float)
signal became_full
signal unlocked

var value: float = 0.0
var unlocked_flag: bool = false

var _since_gain: float = 0.0


func get_max() -> float:
	return maxf(CombatTuning.current().mana_max, 1.0)


func is_unlocked() -> bool:
	return unlocked_flag


func is_full() -> bool:
	return unlocked_flag and value >= get_max() - 0.001


func get_ratio() -> float:
	return clampf(value / get_max(), 0.0, 1.0)


## Nhặt Ultimate: thanh mana xuất hiện, luôn bắt đầu ở 0.
func unlock() -> void:
	unlocked_flag = true
	value = 0.0
	_since_gain = 0.0
	unlocked.emit()
	changed.emit(value, get_max())


## Chơi lại: khóa và xóa mana.
func lock() -> void:
	unlocked_flag = false
	value = 0.0
	changed.emit(value, get_max())


func gain(amount: float) -> void:
	if not unlocked_flag or amount <= 0.0:
		return
	var was_full := is_full()
	value = minf(value + amount, get_max())
	_since_gain = 0.0
	changed.emit(value, get_max())
	if not was_full and is_full():
		became_full.emit()


## Dùng toàn bộ mana cho Ultimate. Trả về false nếu chưa đầy.
func consume() -> bool:
	if not is_full():
		return false
	value = 0.0
	_since_gain = 0.0
	changed.emit(value, get_max())
	return true


func _process(delta: float) -> void:
	if not unlocked_flag or value <= 0.0 or is_full():
		return
	_since_gain += delta
	if _since_gain < CombatTuning.current().mana_decay_delay:
		return
	value = maxf(value - CombatTuning.current().mana_decay_per_second * delta, 0.0)
	changed.emit(value, get_max())
