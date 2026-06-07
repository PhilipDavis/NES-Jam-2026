extends RichTextLabel

const REVEAL_DURATION := 0.4

var wall_jumped := false
var activated := false
var is_done := false

func _ready() -> void:
	visible_ratio = 0.0
	Events.game_started.connect(_on_game_started)
	Events.tutorial_step_completed.connect(_on_tutorial_step_completed)
	Events.player_jumped.connect(_on_player_jumped)
	Events.player_attacked.connect(_on_player_attacked)

func _on_game_started() -> void:
	if Settings.get_setting('tutorial', 'attack', false):
		is_done = true
		Events.tutorial_step_completed.emit('attack')
		get_parent().remove_child(self)
		queue_free()
		return

func _on_tutorial_step_completed(step: String) -> void:
	if step == 'wall-jump' and not is_done and not activated:
		activated = true
		await get_tree().create_timer(1.0).timeout
		_reveal()

func _on_player_jumped(wall_jump: bool) -> void:
	if wall_jump and not is_done and not activated:
		activated = true
		await get_tree().create_timer(1.0).timeout
		_reveal()

func _on_player_attacked() -> void:
	if is_done:
		return
	is_done = true
	_hide()
	Events.tutorial_step_completed.emit('attack')

func _reveal() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'visible_ratio', 1.0, REVEAL_DURATION)

func _hide() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'visible_ratio', 0.0, REVEAL_DURATION / 2)
