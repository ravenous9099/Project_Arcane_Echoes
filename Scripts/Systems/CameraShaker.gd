class_name CameraShaker
extends Node
## Rung camera (va chạm mạnh, Boss đổi giai đoạn, Boss chết...). Main gán camera của Player; nơi khác chỉ gọi shake().
## intensity_multiplier chỉnh được trong Inspector (0 = tắt hẳn rung màn hình, dành cho người dễ say hoặc muốn tắt).

@export_range(0.0, 2.0, 0.05) var intensity_multiplier: float = 1.0

var camera: Camera2D = null

var _strength: float = 0.0
var _duration: float = 0.1
var _time_left: float = 0.0


## Rung với cường độ strength (pixel) giảm dần trong duration giây. Không làm yếu đi một cú rung mạnh hơn đang diễn ra.
func shake(strength: float, duration: float) -> void:
	var scaled := strength * intensity_multiplier * CombatTuning.current().shake_multiplier
	if scaled <= 0.0:
		return
	var current := _strength * (_time_left / _duration) if _time_left > 0.0 else 0.0
	if scaled < current:
		return
	_strength = scaled
	_duration = maxf(duration, 0.05)
	_time_left = _duration


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _time_left > 0.0:
		_time_left -= delta
		var k := clampf(_time_left / _duration, 0.0, 1.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * k
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
