extends RichTextLabel

const REVEAL_DURATION := 0.8

func _ready() -> void:
	visible_ratio = 0.0
	Events.game_started.connect(_on_game_started)
	Events.player_jumped.connect(_on_player_jumped)

func _on_game_started() -> void:
	_reveal()
	
func _on_player_jumped(_wall_jump: bool) -> void:
	Events.tutorial_step_completed.emit('ground-jump')
	_hide()

func _reveal() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'visible_ratio', 1.0, REVEAL_DURATION)

func _hide() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'visible_ratio', 0.0, REVEAL_DURATION / 2)
