extends Node
## Autoload "PlayerStats": gộp buff của combo và relic thành các hệ số mà Player, SpellSystem, Enemy dùng.
## Một nơi duy nhất để biết "sát thương cuối cùng nhân bao nhiêu", "hồi chiêu giảm bao nhiêu"...

signal stats_changed

const MAX_COOLDOWN_REDUCTION: float = 0.6
const BASE_MAX_HEALTH: float = 100.0


func _ready() -> void:
	RelicSystem.relics_changed.connect(func() -> void: stats_changed.emit())


## Hệ số sát thương Player gây ra = chỉnh tay (CombatTuning) * (1 + buff combo + relic).
func damage_multiplier() -> float:
	var base := CombatTuning.current().player_damage_multiplier
	return base * (1.0 + ComboSystem.get_damage_bonus() + RelicSystem.sum_stat(&"damage_pct"))


## Hệ số nhân thời gian hồi chiêu (< 1 = hồi nhanh hơn).
func cooldown_multiplier() -> float:
	var reduction := ComboSystem.get_cooldown_reduction() + RelicSystem.sum_stat(&"cooldown_pct")
	return 1.0 - clampf(reduction, 0.0, MAX_COOLDOWN_REDUCTION)


func move_speed_multiplier() -> float:
	return 1.0 + RelicSystem.sum_stat(&"move_speed_pct")


func max_health_multiplier() -> float:
	return 1.0 + RelicSystem.sum_stat(&"max_hp_pct")


func kill_heal_amount() -> float:
	return ComboSystem.get_kill_heal() + RelicSystem.sum_stat(&"kill_heal")


func gold_multiplier() -> float:
	return 1.0 + RelicSystem.sum_stat(&"gold_pct")


func hp_drop_bonus() -> float:
	return RelicSystem.sum_stat(&"hp_drop_bonus")
