extends Node
## Autoload "Wallet": số vàng người chơi đang có (giữ qua các level, được lưu trong save).

signal gold_changed(gold: int, delta: int)

var gold: int = 0


## earned = true: tính vào "vàng đã kiếm" của lượt chơi (nhặt vàng); false cho tiền bán relic.
func add(amount: int, earned: bool = true) -> void:
	if amount <= 0:
		return
	if earned:
		RunStats.add_gold_earned(amount)
	gold += amount
	gold_changed.emit(gold, amount)


func spend(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold, -amount)
	return true


func reset() -> void:
	var old := gold
	gold = 0
	gold_changed.emit(gold, -old)


func set_gold(value: int) -> void:
	var old := gold
	gold = maxi(value, 0)
	gold_changed.emit(gold, gold - old)
