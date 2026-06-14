extends CharacterBody2D
class_name Enemy

const FLICKER_DURATION := 400
const FLICKER_STEP := 100

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D

# Note: this @onready does nothing because the screen (with enemies) loads before the player
@onready var player := get_tree().get_first_node_in_group('player') as Player

@export var attack_damage := 1
@export var facing_direction := 1:
	set(value):
		facing_direction = signf(value)
		if is_node_ready():
			visuals.scale.x = facing_direction

var die_direction := 0.0
var is_flickering := false

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	Events.screen_ready.connect(_on_screen_ready)

func _on_screen_ready(screen: Node2D) -> void:
	if not screen.is_ancestor_of(self):
		return
	set_process(true)
	set_physics_process(true)
	
	# Can disconnect the event handler now that our screen has become ready
	Events.screen_ready.disconnect(_on_screen_ready)

func _play_animation(anim: String) -> void:
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)

func _flicker() -> void:
	if is_flickering:
		return
	
	is_flickering = true
	
	for i in range(0, FLICKER_DURATION / FLICKER_STEP):
		await get_tree().create_timer(FLICKER_STEP / 2000.0).timeout
		sprite.visible = false
		await get_tree().create_timer(FLICKER_STEP / 2000.0).timeout
		sprite.visible = true
	
	is_flickering = false
