extends Node
## Autoload "GameManager": quản lý TRẠNG THÁI LƯỢT CHƠI (đang chạy / kết thúc) và tạm dừng game.
## Các hệ thống khác (EnemySpawner...) lắng nghe signal ở đây thay vì tự đoán trạng thái.
## Lưu ý: không đặt class_name cho script này (tên GameManager đã dành cho Autoload).

signal run_started
## reason ví dụ: &"player_died".
signal run_ended(reason: StringName)
signal pause_changed(is_paused: bool)

var is_run_active: bool = false

## Bật để dùng phím P tạm dừng/tiếp tục game khi thử nghiệm.
@export var debug_pause_key_enabled: bool = true


func _ready() -> void:
	# Phải luôn chạy kể cả khi game đang tạm dừng, nếu không sẽ không bấm P để tiếp tục được.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if debug_pause_key_enabled and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		toggle_pause()


func start_run() -> void:
	get_tree().paused = false
	is_run_active = true
	run_started.emit()


func end_run(reason: StringName = &"ended") -> void:
	if not is_run_active:  # chặn gọi trùng
		return
	is_run_active = false
	run_ended.emit(reason)
	print("[GameManager] Lượt chơi kết thúc: ", reason)


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_changed.emit(get_tree().paused)
	print("[GameManager] Tạm dừng: ", get_tree().paused)
