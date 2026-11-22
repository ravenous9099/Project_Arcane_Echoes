class_name SfxPlayer
extends Node
## Phát hiệu ứng âm thanh qua một "bể" các AudioStreamPlayer dùng lại (không tạo node mới mỗi lần phát).
## Dùng ở bất kỳ đâu: SfxPlayer.play_sfx(&"hit_light"). Nếu chưa có SfxPlayer nào trong cây (ví dụ chạy scene riêng) thì bỏ qua, không lỗi.
## Âm lượng và bật/tắt lấy từ CombatTuning (người chơi chỉnh trong menu tạm dừng).

const POOL_SIZE: int = 14

static var instance: SfxPlayer = null

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # vẫn phát được trong lúc hitstop/pause
	instance = self
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func _exit_tree() -> void:
	if instance == self:
		instance = null


## offset_db: chỉnh to/nhỏ riêng cho lần phát này. pitch: 1.0 = nguyên bản.
static func play_sfx(sfx_name: StringName, offset_db: float = 0.0, pitch: float = 1.0) -> void:
	if instance != null:
		instance._play(sfx_name, offset_db, pitch)


func _play(sfx_name: StringName, offset_db: float, pitch: float) -> void:
	var tuning := CombatTuning.current()
	if not tuning.sfx_enabled:
		return
	var stream := ProceduralSfx.get_stream(sfx_name)
	if stream == null:
		return
	# Tìm player đang rảnh; không có thì lấy vòng tròn (đè lên âm cũ nhất).
	var chosen: AudioStreamPlayer = null
	for i in POOL_SIZE:
		var candidate := _players[(_next + i) % POOL_SIZE]
		if not candidate.playing:
			chosen = candidate
			_next = (_next + i + 1) % POOL_SIZE
			break
	if chosen == null:
		chosen = _players[_next]
		_next = (_next + 1) % POOL_SIZE
	chosen.stream = stream
	chosen.volume_db = tuning.sfx_volume_db + offset_db
	chosen.pitch_scale = pitch * randf_range(0.96, 1.04)
	chosen.play()
