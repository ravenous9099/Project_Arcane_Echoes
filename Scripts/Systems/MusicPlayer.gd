extends Node
## Autoload "MusicPlayer": nhạc nền có crossfade. Gọi MusicPlayer.play_track(&"explore") từ bất kỳ đâu.
## Cùng bài đang phát thì không làm gì. Tự hạ nhỏ khi tạm dừng (duck). Âm lượng/bật-tắt lấy từ CombatTuning.

const TRACKS := {
	&"menu": "res://Audio/Music/theme_menu_hub.ogg",
	&"hub": "res://Audio/Music/theme_menu_hub.ogg",
	&"ending": "res://Audio/Music/theme_menu_hub.ogg",
	&"explore": "res://Audio/Music/theme_explore.ogg",
	&"boss": "res://Audio/Music/theme_boss.ogg",
}
const FADE_TIME := 1.2
const SILENT_DB := -60.0
const PAUSE_DUCK_DB := -10.0

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current_file: String = ""
var _current_name: StringName = &""
var _streams: Dictionary = {}
var _tween: Tween = null
var _duck_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("pause_changed"):
		gm.connect("pause_changed", _on_pause_changed)


func current_track() -> StringName:
	return _current_name


## Phát bài theo tên (menu/hub/explore/boss/ending). Cùng file đang phát -> giữ nguyên, không khởi động lại.
func play_track(track: StringName, fade: float = FADE_TIME) -> void:
	_current_name = track
	var path: String = TRACKS.get(track, "")
	if path == "":
		push_warning("MusicPlayer: không có bài '%s'." % track)
		return
	if path == _current_file and _players[_active].playing:
		_apply_volume(0.3)
		return
	var stream := _load(path)
	if stream == null:
		return
	_current_file = path
	var old := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(incoming, "volume_db", _target_db(), fade)
	if old.playing:
		_tween.tween_property(old, "volume_db", SILENT_DB, fade)
		_tween.chain().tween_callback(old.stop)


func stop(fade: float = FADE_TIME) -> void:
	_current_file = ""
	_current_name = &""
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	for p in _players:
		if p.playing:
			_tween.tween_property(p, "volume_db", SILENT_DB, fade)
	_tween.chain().tween_callback(_stop_all)


## Gọi khi người chơi đổi âm lượng/bật-tắt nhạc trong menu.
func refresh_volume() -> void:
	_apply_volume(0.1)


func _apply_volume(time: float) -> void:
	if _current_file == "":
		return
	var p := _players[_active]
	if not p.playing:
		p.play()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(p, "volume_db", _target_db(), time)


func _target_db() -> float:
	var tuning := CombatTuning.current()
	if not tuning.music_enabled:
		return SILENT_DB
	return tuning.music_volume_db + _duck_db


func _on_pause_changed(is_paused: bool) -> void:
	_duck_db = PAUSE_DUCK_DB if is_paused else 0.0
	_apply_volume(0.25)


func _stop_all() -> void:
	for p in _players:
		p.stop()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("MusicPlayer: thiếu file %s." % path)
		return null
	var s := load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_streams[path] = s
	return s
