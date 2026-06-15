extends CanvasLayer

@onready var health_label := %HealthLabel
@onready var hearts_container := %HeartsContainer
@onready var time_label := %TimeLabel
@onready var time_value := %TimeValue

var life_texture: Texture2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Events.time_changed.connect(_on_time_changed)
	Events.player_health_changed.connect(_on_player_health_changed)
	life_texture = load('res://menu/Frog-Head.png')
	for life in hearts_container.get_children():
		life.visible = false

func _on_time_changed(total_seconds: int) -> void:
	time_value.text = Utils.format_time(total_seconds)

func _on_player_health_changed(health: int, was_lost: bool) -> void:
	for i in range(hearts_container.get_child_count()):
		var life := hearts_container.get_child(i)
		var was_visible = life.visible
		
		# Blink and increase rapidly until it disappears
		# (but only when was_lost is true... other times
		# we may reduce health e.g. when switching from
		# Easy difficulty to Nightmare difficulty)
		if was_visible and i >= health and was_lost:
			var tween = create_tween()
			var delay := 0.18
			while delay >= 0.08:
				tween.tween_callback(func(): life.visible = false)
				tween.tween_interval(delay)
				tween.tween_callback(func(): life.visible = true)
				tween.tween_interval(delay)
				delay /= 1.5
			await tween.finished
		
		life.visible = i < health
