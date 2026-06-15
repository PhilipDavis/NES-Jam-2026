extends RichTextLabel

const REVEAL_DURATION := 0.4

var ground_jump_tutorial_completed := false
var activated := false
var failed_jumps := 0
var is_done := false

func _ready() -> void:
	visible_ratio = 0.0
	Events.game_started.connect(_on_game_started)
	Events.tutorial_step_completed.connect(_on_tutorial_step_completed)
	Events.player_jumped.connect(_on_player_jumped)
	Events.player_landed.connect(_on_player_landed)

func _on_game_started(demo_mode: bool) -> void:
	if demo_mode:
		queue_free()
		return
	
	if Settings.get_setting('tutorial', 'wall-jump', false):
		is_done = true
		Events.tutorial_step_completed.emit('wall-jump')
		var parent := get_parent()
		if parent:
			parent.remove_child(self)
		queue_free()
		return

func _on_tutorial_step_completed(step: String) -> void:
	if step == 'ground-jump':
		ground_jump_tutorial_completed = true

func _on_player_jumped(wall_jump: bool) -> void:
	if wall_jump and not is_done:
		is_done = true
		_hide()
		Events.tutorial_step_completed.emit('wall-jump')

func _on_player_landed() -> void:
	if not activated or is_done:
		return
	failed_jumps += 1
	activated = false # Make player fail twice
	if failed_jumps == 2:
		_reveal()

# This is triggered when the player jumps through an
# area that indicates they tried to jump to a higher
# platform but missed because they didn't wall jump.
func activate() -> void:
	if ground_jump_tutorial_completed and not is_done:
		activated = true

func _reveal() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'visible_ratio', 1.0, REVEAL_DURATION)

func _hide() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'visible_ratio', 0.0, REVEAL_DURATION / 2)
