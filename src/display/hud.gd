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
	var seconds := total_seconds % 60
	var minutes := mini((total_seconds - seconds) / 60, 999)
	time_value.text = "%d:%02d" % [ minutes, seconds ]

func _on_player_health_changed(health: int, was_lost: bool) -> void:
	for i in range(hearts_container.get_child_count()):
		var life := hearts_container.get_child(i)
		life.visible = i < health
		# TODO: animate gained and lost lives
