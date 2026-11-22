class_name GameSettings
extends RefCounted
## Cài đặt người chơi lưu bền giữa các lần chạy (user://arcane_settings.cfg): rung màn hình, hitstop, âm lượng, số sát thương.
## Nạp vào CombatTuning lúc khởi động; menu tạm dừng gọi save_from() mỗi khi người chơi chỉnh.

const PATH := "user://arcane_settings.cfg"


static func load_into(tuning: CombatTuning) -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return  # chưa có file: dùng giá trị trong combat_tuning.tres
	tuning.shake_multiplier = clampf(float(config.get_value("feel", "shake", tuning.shake_multiplier)), 0.0, 2.0)
	tuning.hitstop_enabled = bool(config.get_value("feel", "hitstop", tuning.hitstop_enabled))
	tuning.damage_numbers_enabled = bool(config.get_value("feel", "damage_numbers", tuning.damage_numbers_enabled))
	tuning.sfx_enabled = bool(config.get_value("audio", "sfx_enabled", tuning.sfx_enabled))
	tuning.sfx_volume_db = clampf(float(config.get_value("audio", "sfx_volume_db", tuning.sfx_volume_db)), -40.0, 6.0)

	tuning.music_enabled = bool(config.get_value("audio", "music_enabled", tuning.music_enabled))
	tuning.music_volume_db = clampf(float(config.get_value("audio", "music_volume_db", tuning.music_volume_db)), -40.0, 6.0)


static func save_from(tuning: CombatTuning) -> void:
	var config := ConfigFile.new()
	config.set_value("feel", "shake", tuning.shake_multiplier)
	config.set_value("feel", "hitstop", tuning.hitstop_enabled)
	config.set_value("feel", "damage_numbers", tuning.damage_numbers_enabled)
	config.set_value("audio", "sfx_enabled", tuning.sfx_enabled)
	config.set_value("audio", "sfx_volume_db", tuning.sfx_volume_db)
	config.set_value("audio", "music_enabled", tuning.music_enabled)
	config.set_value("audio", "music_volume_db", tuning.music_volume_db)
	var err := config.save(PATH)
	if err != OK:
		push_warning("GameSettings: không lưu được cài đặt (%s)." % error_string(err))
