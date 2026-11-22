class_name ProceduralSfx
extends RefCounted
## Âm thanh hiệu ứng TỔNG HỢP bằng code (project chưa có file âm thanh). Mỗi tên trả về một AudioStreamWAV 16-bit mono, tạo một lần rồi lưu đệm.
## Khi có file âm thanh thật, chỉ cần gán vào SpellData.cast_sound/hit_sound hoặc thay hàm get_stream() ở đây; phần gọi âm thanh trong game không đổi.
## Tên hiệu ứng: hit_light, hit_heavy, enemy_die, cast, dash, player_hurt, warn, warn_boss, boom, roar, pickup, unlock, perfect, portal.

const RATE: int = 22050

static var _cache: Dictionary = {}


static func get_stream(sfx_name: StringName) -> AudioStreamWAV:
	if _cache.has(sfx_name):
		return _cache[sfx_name] as AudioStreamWAV
	var samples := _render(sfx_name)
	var stream: AudioStreamWAV = null
	if not samples.is_empty():
		stream = _to_stream(samples)
	_cache[sfx_name] = stream
	return stream


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


## Dựng mẫu âm theo công thức từng hiệu ứng. Tiếng ồn dùng seed cố định nên hiệu ứng luôn giống nhau giữa các lần chạy.
static func _render(sfx_name: StringName) -> PackedFloat32Array:
	match sfx_name:
		&"hit_light":
			return _mix([_noise(0.06, 5.0, 0.5, 1), _sweep(180.0, 90.0, 0.06, 6.0, 0.5)])
		&"hit_heavy":
			return _mix([_noise(0.11, 4.0, 0.7, 2), _sweep(130.0, 50.0, 0.13, 4.0, 0.8)])
		&"enemy_die":
			return _mix([_sweep(320.0, 60.0, 0.28, 3.0, 0.5), _noise(0.22, 5.0, 0.35, 3)])
		&"cast":
			return _sweep(380.0, 900.0, 0.13, 3.5, 0.35)
		&"dash":
			return _whoosh(0.17, 0.5)
		&"player_hurt":
			return _mix([_sweep(240.0, 110.0, 0.2, 4.0, 0.55, true), _noise(0.12, 6.0, 0.35, 4)])
		&"warn":
			return _concat([_sweep(880.0, 880.0, 0.05, 2.0, 0.22), _silence(0.03), _sweep(880.0, 880.0, 0.05, 2.0, 0.22)])
		&"warn_boss":
			return _sweep(440.0, 700.0, 0.26, 2.5, 0.4)
		&"boom":
			return _mix([_sweep(95.0, 32.0, 0.5, 3.0, 0.9), _noise(0.4, 4.0, 0.5, 5)])
		&"roar":
			return _mix([_sweep(80.0, 48.0, 0.85, 1.6, 0.8, true), _noise(0.8, 2.2, 0.4, 6)])
		&"pickup":
			return _concat([_sweep(660.0, 660.0, 0.06, 2.5, 0.3), _sweep(880.0, 880.0, 0.06, 2.5, 0.3), _sweep(1320.0, 1320.0, 0.1, 2.5, 0.3)])
		&"unlock":
			return _mix([_sweep(300.0, 1200.0, 0.42, 2.0, 0.35), _sweep(450.0, 1800.0, 0.42, 2.0, 0.18)])
		&"perfect":
			return _mix([_sweep(1200.0, 1200.0, 0.16, 5.0, 0.35), _sweep(1800.0, 1800.0, 0.16, 6.0, 0.2)])
		&"portal":
			return _mix([_sweep(200.0, 1500.0, 0.65, 1.6, 0.35), _whoosh(0.65, 0.3)])
		&"ui_hover":
			return _sweep(1400.0, 1500.0, 0.03, 4.0, 0.12)
		&"ui_click":
			return _mix([_sweep(900.0, 600.0, 0.06, 4.0, 0.3), _noise(0.02, 6.0, 0.12, 11)])
		&"ui_confirm":
			return _concat([_sweep(660.0, 660.0, 0.06, 2.5, 0.28), _sweep(990.0, 990.0, 0.12, 3.0, 0.28)])
		&"ui_back":
			return _concat([_sweep(700.0, 700.0, 0.05, 2.5, 0.25), _sweep(480.0, 480.0, 0.09, 3.0, 0.25)])
		&"ui_error":
			return _concat([_sweep(220.0, 200.0, 0.08, 2.0, 0.3, true), _silence(0.02), _sweep(180.0, 160.0, 0.12, 2.5, 0.3, true)])
		&"type":
			return _mix([_noise(0.025, 8.0, 0.2, 12), _sweep(1100.0, 900.0, 0.025, 6.0, 0.12)])
		&"coin":
			return _concat([_sweep(1568.0, 1568.0, 0.05, 2.0, 0.25), _sweep(2093.0, 2093.0, 0.14, 4.0, 0.25)])
		&"buy":
			return _concat([_sweep(1568.0, 1568.0, 0.05, 2.0, 0.25), _sweep(1976.0, 1976.0, 0.05, 2.0, 0.25), _sweep(2637.0, 2637.0, 0.16, 4.0, 0.25)])
		&"sell":
			return _concat([_sweep(1760.0, 1760.0, 0.05, 2.5, 0.25), _sweep(1175.0, 1175.0, 0.12, 3.5, 0.25)])
		&"heal":
			return _concat([_sweep(520.0, 520.0, 0.07, 2.5, 0.26), _sweep(660.0, 660.0, 0.07, 2.5, 0.26), _sweep(784.0, 784.0, 0.14, 3.0, 0.26)])
		&"equip":
			return _mix([_sweep(500.0, 900.0, 0.1, 3.0, 0.3), _noise(0.04, 6.0, 0.2, 13)])
		&"unequip":
			return _mix([_sweep(800.0, 420.0, 0.1, 3.0, 0.3), _noise(0.04, 6.0, 0.15, 14)])
		&"rank_up":
			return _concat([_sweep(523.0, 523.0, 0.06, 2.0, 0.28), _sweep(659.0, 659.0, 0.06, 2.0, 0.28), _sweep(784.0, 784.0, 0.06, 2.0, 0.28), _sweep(1047.0, 1047.0, 0.16, 3.0, 0.3)])
		&"rank_down":
			return _concat([_sweep(520.0, 520.0, 0.07, 2.5, 0.28, true), _sweep(390.0, 390.0, 0.07, 2.5, 0.28, true), _sweep(260.0, 260.0, 0.14, 3.0, 0.28, true)])
		&"ultimate_get":
			return _mix([_sweep(220.0, 1760.0, 0.6, 1.6, 0.35), _sweep(330.0, 2640.0, 0.6, 1.8, 0.18), _whoosh(0.5, 0.2)])
		&"ultimate_ready":
			return _concat([_sweep(784.0, 784.0, 0.07, 2.0, 0.3), _sweep(1047.0, 1047.0, 0.07, 2.0, 0.3), _sweep(1568.0, 1568.0, 0.25, 3.0, 0.3)])
		&"mana_full":
			return _mix([_sweep(400.0, 1000.0, 0.22, 2.5, 0.3), _sweep(600.0, 1500.0, 0.22, 2.5, 0.15)])
		&"goal":
			return _mix([_concat([_sweep(523.0, 523.0, 0.1, 2.0, 0.3), _sweep(659.0, 659.0, 0.1, 2.0, 0.3), _sweep(784.0, 784.0, 0.3, 2.5, 0.3)]), _sweep(262.0, 262.0, 0.5, 2.0, 0.18)])
		&"level_start":
			return _mix([_sweep(120.0, 300.0, 0.5, 2.0, 0.5), _whoosh(0.45, 0.3)])
		&"pause":
			return _concat([_sweep(800.0, 800.0, 0.05, 2.5, 0.22), _sweep(560.0, 560.0, 0.08, 3.0, 0.22)])
		&"resume":
			return _concat([_sweep(560.0, 560.0, 0.05, 2.5, 0.22), _sweep(800.0, 800.0, 0.08, 3.0, 0.22)])
		&"game_over":
			return _mix([_concat([_sweep(330.0, 330.0, 0.2, 2.0, 0.35, true), _sweep(247.0, 247.0, 0.25, 2.0, 0.35, true), _sweep(165.0, 120.0, 0.7, 2.0, 0.4, true)]), _noise(0.6, 3.0, 0.15, 15)])
		&"victory":
			return _mix([_concat([_sweep(523.0, 523.0, 0.14, 2.0, 0.3), _sweep(659.0, 659.0, 0.14, 2.0, 0.3), _sweep(784.0, 784.0, 0.14, 2.0, 0.3), _sweep(1047.0, 1047.0, 0.7, 2.2, 0.32)]), _sweep(131.0, 131.0, 1.1, 1.8, 0.2)])
		&"fire":
			return _mix([_noise(0.22, 3.0, 0.45, 16), _sweep(300.0, 700.0, 0.2, 3.0, 0.3, true)])
		&"ice":
			return _mix([_sweep(2200.0, 1400.0, 0.2, 3.5, 0.25), _sweep(3300.0, 2100.0, 0.18, 4.0, 0.15), _noise(0.08, 6.0, 0.15, 17)])
		&"shadow":
			return _mix([_sweep(220.0, 70.0, 0.32, 2.5, 0.5, true), _whoosh(0.3, 0.3)])
		&"shield":
			return _mix([_sweep(300.0, 600.0, 0.3, 2.0, 0.3), _sweep(450.0, 900.0, 0.3, 2.0, 0.18)])
		&"enemy_atk":
			return _mix([_whoosh(0.14, 0.35), _sweep(260.0, 140.0, 0.1, 5.0, 0.25)])
		&"chest":
			return _mix([_noise(0.1, 4.0, 0.3, 18), _sweep(300.0, 500.0, 0.12, 3.0, 0.3), _sweep(900.0, 1300.0, 0.2, 3.0, 0.15)])
		&"save":
			return _concat([_sweep(880.0, 880.0, 0.06, 2.0, 0.25), _sweep(1109.0, 1109.0, 0.06, 2.0, 0.25), _sweep(1319.0, 1319.0, 0.18, 3.0, 0.25)])
		&"step":
			return _noise(0.04, 8.0, 0.15, 19)
	return PackedFloat32Array()


## Sóng sin có tần số chạy từ f0 tới f1, biên độ giảm dần theo hàm mũ (decay càng lớn tắt càng nhanh).
## square_mix = true: trộn thêm sóng vuông cho tiếng "gắt".
static func _sweep(f0: float, f1: float, duration: float, decay: float, volume: float, square_mix: bool = false) -> PackedFloat32Array:
	var count := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(count)
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / float(RATE)
		var s := sin(phase)
		if square_mix:
			s = 0.6 * s + 0.4 * signf(s)
		var attack := minf(float(i) / 80.0, 1.0)  # vào nhẹ để không bị tiếng "lụp"
		out[i] = s * exp(-decay * t) * attack * volume
	return out


## Tiếng ồn trắng giảm dần theo hàm mũ.
static func _noise(duration: float, decay: float, volume: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(count)
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-decay * t) * volume
	return out


## Tiếng "vút": ồn lọc thông thấp, biên độ lên rồi xuống, bộ lọc mở dần.
static func _whoosh(duration: float, volume: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var lp := 0.0
	for i in count:
		var t := float(i) / float(count)
		var coeff := lerpf(0.08, 0.5, t)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * coeff
		out[i] = lp * sin(PI * t) * volume * 2.0
	return out


static func _silence(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	return out


## Cộng nhiều lớp âm chồng lên nhau (độ dài lấy theo lớp dài nhất).
static func _mix(layers: Array) -> PackedFloat32Array:
	var length := 0
	for layer: PackedFloat32Array in layers:
		length = maxi(length, layer.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for layer: PackedFloat32Array in layers:
		for i in layer.size():
			out[i] += layer[i]
	# Chuẩn hóa nếu các lớp cộng lại vượt biên độ cho phép (tránh méo tiếng do bị cắt).
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	if peak > 0.95:
		var gain := 0.95 / peak
		for i in out.size():
			out[i] *= gain
	return out


## Nối các đoạn âm nối tiếp nhau.
static func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		out.append_array(part)
	return out
