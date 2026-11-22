class_name DebugStats
extends CanvasLayer
## Bảng đo hiệu năng trong game (phím F1). Mục tiêu: 60 FPS = 16,7 ms mỗi khung hình.
## Đo thời gian THỰC mỗi khung (không bị hitstop/slow-mo làm sai) trong 240 khung gần nhất: trung bình, p95, lớn nhất, số lần giật (> 25 ms).
## Kèm các chỉ số của Godot (thời gian process/physics, draw call, số node), số Enemy và đạn, thời gian sinh map, và dòng bổ sung do Main cung cấp.

const WINDOW: int = 240
const HITCH_MS: float = 25.0

## Map để lấy thời gian sinh map. Main gán.
var world: MapGenerator = null
## Hàm trả về chuỗi bổ sung (ví dụ trạng thái học của Boss). Main gán.
var extra_text: Callable = Callable()

var _label: Label
var _frames: PackedFloat32Array = PackedFloat32Array()
var _write_index: int = 0
var _last_usec: int = 0
var _refresh_msec: int = 0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frames.resize(WINDOW)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 10.0
	panel.offset_bottom = -10.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_panel(panel, 12, 8.0)
	add_child(panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_label(_label, 12, 3, Color(0.85, 1.0, 0.85))
	panel.add_child(_label)
	visible = false


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frames[_write_index] = float(now - _last_usec) / 1000.0
		_write_index = (_write_index + 1) % WINDOW
	_last_usec = now
	if not visible:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _refresh_msec < 250:
		return
	_refresh_msec = now_msec
	_label.text = _build_text()


func _build_text() -> String:
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	var worst := 0.0
	var hitches := 0
	var samples := 0
	for ms in _frames:
		if ms <= 0.0:
			continue
		samples += 1
		total += ms
		worst = maxf(worst, ms)
		if ms > HITCH_MS:
			hitches += 1
	var average := total / float(maxi(samples, 1))
	var p95 := sorted[int(WINDOW * 0.95)]
	var lines := PackedStringArray()
	lines.append("FPS %d | khung TB %.1f ms | p95 %.1f | lớn nhất %.1f | giật(>%d ms) %d/%d" % [
		int(Engine.get_frames_per_second()), average, p95, worst, int(HITCH_MS), hitches, samples])
	lines.append("Process %.1f ms | Physics %.1f ms | Draw call %d | Vật thể vẽ %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	lines.append("Node %d | Object %d | Bộ nhớ %.0f MB" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	lines.append("Enemy %d | Đạn/vùng nổ của Enemy %d | time_scale %.2f%s" % [
		get_tree().get_nodes_in_group("enemies").size(), get_tree().get_nodes_in_group("enemy_attacks").size(), Engine.time_scale,
		" | sinh map %.0f ms" % world.last_generation_ms if world != null else ""])
	if extra_text.is_valid():
		var extra: String = extra_text.call()
		if not extra.is_empty():
			lines.append(extra)
	return "\n".join(lines)
