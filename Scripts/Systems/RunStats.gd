extends Node
## Autoload "RunStats": số liệu của MỘT lượt chơi (tên người chơi, thời gian sống sót, số lần dùng spell, tổng sát thương, số địch hạ gục,
## relic đã mua, vàng đã kiếm...) để ghi vào Hall of Fame khi lượt chơi kết thúc (chết hoặc thắng).
## Tên người chơi (player_name) nhập ở menu chính khi bấm "Chơi mới", giữ qua các lượt và nhớ ở user://profile.json.
## Lưu ý: không đặt class_name (tên RunStats dành cho Autoload).

const PROFILE_PATH := "user://profile.json"
const MAX_NAME_LENGTH: int = 16
const DEFAULT_NAME := "Lữ khách"

signal stats_changed

var player_name: String = DEFAULT_NAME
## Giây chơi thật (không tính lúc tạm dừng, không tính lúc đang ở menu).
var survival_time: float = 0.0
var spells_cast: int = 0
var damage_dealt: float = 0.0
var kills: int = 0
var bosses_defeated: int = 0
var relics_bought: int = 0
var gold_earned: int = 0
## Hạng combo cao nhất đạt được (chỉ số 0..7 trong ComboSystem.RANK_NAMES).
var best_rank: int = 0
var levels_cleared: int = 0
var recorded: bool = false  # đã ghi Hall of Fame cho lượt này chưa (chặn ghi 2 lần)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_profile()
	SpellSystem.spell_cooldown_started.connect(func(_s: SpellData, _d: float) -> void: spells_cast += 1)
	ComboSystem.rank_changed.connect(func(rank: int, _up: bool) -> void: best_rank = maxi(best_rank, rank))


func _process(delta: float) -> void:
	if GameManager.is_run_active and not get_tree().paused:
		survival_time += delta


## Bắt đầu lượt mới: xoá số liệu (GIỮ tên người chơi).
func begin_run() -> void:
	survival_time = 0.0
	spells_cast = 0
	damage_dealt = 0.0
	kills = 0
	bosses_defeated = 0
	relics_bought = 0
	gold_earned = 0
	best_rank = 0
	levels_cleared = 0
	recorded = false
	stats_changed.emit()


func set_player_name(value: String) -> void:
	player_name = sanitize_name(value)
	_save_profile()
	stats_changed.emit()


static func sanitize_name(value: String) -> String:
	var cleaned := value.strip_edges().replace("\n", " ").replace("\t", " ")
	if cleaned.length() > MAX_NAME_LENGTH:
		cleaned = cleaned.substr(0, MAX_NAME_LENGTH).strip_edges()
	return cleaned if not cleaned.is_empty() else DEFAULT_NAME


func add_damage(amount: float) -> void:
	if GameManager.is_run_active and amount > 0.0:
		damage_dealt += amount


func add_gold_earned(amount: int) -> void:
	if amount > 0:
		gold_earned += amount


# ---------------------------------------------------------------- Lưu / nạp cùng file lưu tiến trình
func to_dict() -> Dictionary:
	return {
		"survival_time": survival_time, "spells_cast": spells_cast, "damage_dealt": damage_dealt, "kills": kills,
		"bosses_defeated": bosses_defeated, "relics_bought": relics_bought, "gold_earned": gold_earned,
		"best_rank": best_rank, "levels_cleared": levels_cleared,
	}


func load_dict(data: Dictionary) -> void:
	begin_run()
	survival_time = float(data.get("survival_time", 0.0))
	spells_cast = int(data.get("spells_cast", 0))
	damage_dealt = float(data.get("damage_dealt", 0.0))
	kills = int(data.get("kills", 0))
	bosses_defeated = int(data.get("bosses_defeated", 0))
	relics_bought = int(data.get("relics_bought", 0))
	gold_earned = int(data.get("gold_earned", 0))
	best_rank = clampi(int(data.get("best_rank", 0)), 0, ComboSystem.RANK_NAMES.size() - 1)
	levels_cleared = int(data.get("levels_cleared", 0))


## Tạo một dòng dữ liệu (chưa có id/ngày giờ) từ số liệu hiện tại. HallOfFame.submit_run() điền nốt.
func make_entry(score: int, completed: bool, level_reached: String, relic_ids: Array[String]) -> Dictionary:
	return {
		"name": player_name, "score": score, "survival_sec": int(round(survival_time)), "spells_cast": spells_cast,
		"damage_dealt": int(round(damage_dealt)), "kills": kills, "relics_bought": relics_bought, "relics": relic_ids,
		"gold_earned": gold_earned, "best_rank": ComboSystem.RANK_NAMES[best_rank], "bosses_defeated": bosses_defeated,
		"completed": completed, "level_reached": level_reached,
	}


func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		player_name = sanitize_name(String(parsed.get("player_name", DEFAULT_NAME)))


func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"player_name": player_name}))
