class_name BossBrain
extends RefCounted
## "Bộ não" thích nghi của Boss: quan sát hành vi của người chơi và đưa ra điều chỉnh. KHÔNG phải học máy; đây là các
## thống kê trượt (trung bình mũ) đơn giản, minh bạch, rẻ (vài phép tính mỗi frame), luôn có giới hạn để Boss không bao giờ "bất công".
## Boss học được:
##  1. Đòn nào hay TRÚNG người chơi này thì được chọn nhiều hơn, đòn hay bị NÉ thì ít hơn (không bao giờ dưới ~40% mức gốc).
##  2. Thói quen vị trí: hay đứng xa -> nhiều đòn tầm xa/lao; hay đứng sát -> nhiều đập đất; hay đứng yên -> nhiều thiên thạch.
##  3. Hướng di chuyển: nếu người chơi đi thẳng đều thì ngắm ĐÓN ĐẦU (mức đón tỉ lệ với độ "đều" của hướng đi); đi ngoằn ngoèo thì ngắm thẳng.
##  4. Thói quen lướt: hay lướt NGAY khi Boss đang báo trước thì Boss thỉnh thoảng nhử (trì hoãn đòn thêm một chút).
##  5. Áp lực (pressure): lâu không bị trúng thì Boss nghỉ ít hơn; máu Player thấp thì Boss nới tay đôi chút.
## Brain sống trong suốt một lượt chơi (Main giữ), nên sang vòng sau Boss vẫn nhớ người chơi.

# Mã các đòn. PHẢI trùng enum Boss.Pattern (Boss kiểm tra bằng assert lúc khởi động). Không tham chiếu Boss để tránh phụ thuộc vòng.
const SLAM: int = 0
const FAN: int = 1
const CHARGE: int = 2
const METEORS: int = 3
const RING: int = 4
# Đòn cận chiến riêng của Hiệp sĩ tử thần (Boss level 2).
const SPIN: int = 5
const COMBO: int = 6
const LEAP: int = 7
# Đòn tầm xa riêng của Xạ thủ cung dài (Boss level 3).
const SNIPE: int = 8
const TRAPS: int = 9
const BARRAGE: int = 10
const PATTERN_NAMES: Array[String] = ["SLAM", "FAN", "CHARGE", "METEORS", "RING", "SPIN", "COMBO", "LEAP", "SNIPE", "TRAPS", "BARRAGE"]

const WEIGHT_MIN: float = 0.6
const WEIGHT_MAX: float = 1.6
## Hệ số nhân tối thiểu/tối đa sau khi học, để không đòn nào bị loại hẳn hoặc áp đảo hoàn toàn.
const MULT_MIN: float = 0.4
const MULT_MAX: float = 2.5
## Tốc độ cập nhật tỉ lệ trúng mỗi đòn (0..1, càng lớn càng "nhanh quên").
const SUCCESS_RATE: float = 0.35
## Xác suất chọn đòn ngẫu nhiên đều (khó đoán), nhân với strength.
const EXPLORE_CHANCE: float = 0.12
const MAX_LEAD_DISTANCE: float = 260.0
const PRESSURE_MIN: float = 0.85

var enabled: bool = true
## 0 = tắt thích nghi, 1 = bình thường, 2 = rất mạnh.
var strength: float = 1.0
var pressure_cap: float = 1.35

# ---- Thống kê hành vi người chơi (trung bình trượt)
var avg_distance: float = 200.0
var idle_ratio: float = 0.2
## -1..1: hay đi vòng theo chiều nào quanh Boss (dấu của tích có hướng giữa hướng-tới-Player và vận tốc).
var strafe_bias: float = 0.0
var velocity_ema: Vector2 = Vector2.ZERO
var speed_ema: float = 0.0
var dash_in_prep_rate: float = 0.3
var time_since_hit: float = 0.0
var pressure: float = 1.0
var hits_taken: int = 0
var dashes_seen: int = 0
var attacks_observed: int = 0
var pattern_success: Dictionary = {}  # mã đòn -> tỉ lệ trúng trượt (0..1), mặc định 0.5
var pattern_samples: Dictionary = {}  # mã đòn -> số lần đã quan sát


func reset() -> void:
	avg_distance = 200.0
	idle_ratio = 0.2
	strafe_bias = 0.0
	velocity_ema = Vector2.ZERO
	speed_ema = 0.0
	dash_in_prep_rate = 0.3
	time_since_hit = 0.0
	pressure = 1.0
	hits_taken = 0
	dashes_seen = 0
	attacks_observed = 0
	pattern_success.clear()
	pattern_samples.clear()


## Gọi mỗi frame khi Boss đang hoạt động.
func observe(delta: float, boss_pos: Vector2, player_pos: Vector2, player_vel: Vector2, player_hp_ratio: float) -> void:
	if delta <= 0.0:
		return
	var to_player := player_pos - boss_pos
	var dist := to_player.length()
	avg_distance = lerpf(avg_distance, dist, 1.0 - exp(-delta * 0.4))
	var standing := 1.0 if player_vel.length() < 25.0 else 0.0
	idle_ratio = lerpf(idle_ratio, standing, 1.0 - exp(-delta * 0.3))
	var quick := 1.0 - exp(-delta * 2.5)
	velocity_ema = velocity_ema.lerp(player_vel, quick)
	speed_ema = lerpf(speed_ema, player_vel.length(), quick)
	if dist > 1.0 and player_vel.length() > 30.0:
		var side := (to_player / dist).cross(player_vel.normalized())
		strafe_bias = lerpf(strafe_bias, clampf(side, -1.0, 1.0), 1.0 - exp(-delta * 0.5))
	time_since_hit += delta
	var target_pressure := 1.0 + clampf((time_since_hit - 3.0) * 0.05, 0.0, pressure_cap - 1.0)
	if player_hp_ratio < 0.3:
		target_pressure -= 0.12  # Player sắp chết: nới tay một chút
	pressure = clampf(move_toward(pressure, target_pressure, delta * 0.12), PRESSURE_MIN, pressure_cap)


func register_player_hit() -> void:
	hits_taken += 1
	time_since_hit = 0.0
	pressure = maxf(PRESSURE_MIN, pressure - 0.08)


## boss_in_prep: lúc Player bấm lướt, Boss có đang trong giai đoạn báo trước không.
func register_player_dash(boss_in_prep: bool) -> void:
	dashes_seen += 1
	dash_in_prep_rate = lerpf(dash_in_prep_rate, 1.0 if boss_in_prep else 0.0, 0.3)


## Ghi kết quả một đòn: có trúng Player không.
func register_attack_result(pattern: int, hit: bool) -> void:
	var previous: float = pattern_success.get(pattern, 0.5)
	pattern_success[pattern] = lerpf(previous, 1.0 if hit else 0.0, SUCCESS_RATE)
	pattern_samples[pattern] = int(pattern_samples.get(pattern, 0)) + 1
	attacks_observed += 1


## Nhận bảng trọng số gốc {mã đòn: trọng số}, trả về bảng đã điều chỉnh theo những gì Boss đã học.
func adjust_weights(weights: Dictionary) -> Dictionary:
	if not enabled or strength <= 0.0:
		return weights
	var far := clampf((avg_distance - 220.0) / 120.0, 0.0, 1.0)
	var near := clampf((160.0 - avg_distance) / 80.0, 0.0, 1.0)
	var idle := clampf((idle_ratio - 0.25) / 0.5, 0.0, 1.0)
	var out: Dictionary = {}
	for pattern: int in weights.keys():
		var weight: float = weights[pattern]
		var success: float = pattern_success.get(pattern, 0.5)
		var learned := lerpf(WEIGHT_MIN, WEIGHT_MAX, success)
		var habit := 1.0
		match pattern:
			FAN:
				habit += 0.4 * far
			CHARGE:
				habit += 0.5 * far
			METEORS:
				habit += 0.3 * far + 0.5 * idle
			RING:
				habit += 0.3 * far
			SLAM:
				habit += 0.6 * near
			SPIN:
				habit += 0.6 * near
			COMBO:
				habit += 0.4 * near + 0.2 * (1.0 - far)
			LEAP:
				habit += 0.5 * far + 0.3 * idle
			SNIPE:
				habit += 0.5 * far + 0.4 * idle  # hay đứng yên / đứng xa -> bắn tỉa chính xác hơn
			TRAPS:
				habit += 0.5 * idle + 0.3 * near  # hay đứng một chỗ (nấp) -> bẫy
			BARRAGE:
				habit += 0.4 * absf(strafe_bias) + 0.3 * far  # hay đi vòng -> bắn liên tiếp đón đầu
		var multiplier := lerpf(1.0, learned, strength) * lerpf(1.0, habit, strength)
		out[pattern] = weight * clampf(multiplier, MULT_MIN, MULT_MAX)
	return out


## Vị trí Player sau lead_time giây, đón đầu theo vận tốc hiện tại. Mức đón = độ "đều" của hướng đi (đi thẳng -> đón đủ, ngoằn ngoèo -> không đón).
func predict_position(player_pos: Vector2, player_vel: Vector2, lead_time: float) -> Vector2:
	if not enabled or strength <= 0.0:
		return player_pos
	var consistency := 0.0
	if speed_ema > 20.0:
		consistency = clampf(velocity_ema.length() / speed_ema, 0.0, 1.0)
	var lead := player_vel * lead_time * consistency * minf(strength, 1.5)
	if lead.length() > MAX_LEAD_DISTANCE:
		lead = lead.normalized() * MAX_LEAD_DISTANCE
	return player_pos + lead


## Thời gian nhử thêm (giây) cho một đòn báo trước. > 0 khi Player hay lướt sớm.
func get_feint_delay() -> float:
	if not enabled or strength <= 0.0:
		return 0.0
	var excess := dash_in_prep_rate - 0.5
	if excess > 0.0 and randf() < excess * 1.6 * strength:
		return randf_range(0.25, 0.4)
	return 0.0


## Văn bản debug: Boss đã "hiểu" người chơi thế nào.
func debug_text() -> String:
	var rates := PackedStringArray()
	for pattern in range(PATTERN_NAMES.size()):
		if pattern_samples.has(pattern):
			rates.append("%s %d%%(%d)" % [PATTERN_NAMES[pattern], int(float(pattern_success[pattern]) * 100.0), int(pattern_samples[pattern])])
	return "Học: cách TB %d px | đứng yên %d%% | vòng %+.2f | lướt sớm %d%%\nÁp lực %.2f | bị trúng %d | tỉ lệ trúng: %s" % [
		int(avg_distance), int(idle_ratio * 100.0), strafe_bias, int(dash_in_prep_rate * 100.0),
		pressure, hits_taken, ", ".join(rates) if not rates.is_empty() else "chưa có dữ liệu"]
