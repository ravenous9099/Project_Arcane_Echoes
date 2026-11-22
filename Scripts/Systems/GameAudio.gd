extends Node
## Autoload "GameAudio": âm thanh dùng chung toàn game.
## - Giữ một SfxPlayer vĩnh viễn (để menu chính cũng phát được SFX, không phụ thuộc scene Main).
## - Tự gắn tiếng rê chuột / bấm cho MỌI BaseButton khi nó vào cây scene.
## - Nghe các signal toàn cục: combo lên/xuống bậc, trang bị spell, tạm dừng, chết.

var _last_hover_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SfxPlayer.instance == null:
		add_child(SfxPlayer.new())
	get_tree().node_added.connect(_on_node_added)
	ComboSystem.rank_changed.connect(_on_rank_changed)
	SpellSystem.spell_equipped.connect(func(_slot: int, _spell: SpellData) -> void: SfxPlayer.play_sfx(&"equip"))
	SpellSystem.spell_unequipped.connect(func(_slot: int) -> void: SfxPlayer.play_sfx(&"unequip", 0.0, 0.9))
	GameManager.pause_changed.connect(func(p: bool) -> void: SfxPlayer.play_sfx(&"pause" if p else &"resume"))
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.run_started.connect(func() -> void: SfxPlayer.play_sfx(&"level_start", -4.0))


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.pressed.connect(_on_button_pressed)


func _on_button_hover(button: BaseButton) -> void:
	if button.disabled:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < 40:
		return
	_last_hover_msec = now
	SfxPlayer.play_sfx(&"ui_hover", -6.0)


func _on_button_pressed() -> void:
	SfxPlayer.play_sfx(&"ui_click")


func _on_rank_changed(_rank: int, went_up: bool) -> void:
	SfxPlayer.play_sfx(&"rank_up" if went_up else &"rank_down", -3.0)


func _on_run_ended(reason: StringName) -> void:
	if reason == &"player_died":
		SfxPlayer.play_sfx(&"game_over")
		MusicPlayer.stop(1.5)
