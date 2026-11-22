class_name ComboTuning
extends Resource
## Thông số hệ thống combo. Chỉnh trong Resources/combo_tuning.tres. Các mảng có đúng 8 phần tử, ứng với hạng F, D, C, B, A, S, SS, SSS.

@export var points_per_hit: int = 1
@export var points_per_perfect_dodge: int = 2
## (Không còn dùng từ Phase 13: bị thương thì tụt 1 hạng và xoá điểm đang tích.)
@export var points_lost_on_damage: int = 2
## Số điểm để lên 1 hạng.
@export var points_per_rank: int = 5
## Sau từng khoảng này (giây) không tích điểm thì tụt 1 hạng (trừ points_per_rank điểm).
@export var idle_decay_time: float = 2.5
@export var damage_bonus: Array[float] = [0.0, 0.0, 0.05, 0.10, 0.10, 0.15, 0.25, 0.30]
@export var cooldown_reduction: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.10, 0.15, 0.17, 0.22]
@export var kill_heal: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 3.0, 4.0]
