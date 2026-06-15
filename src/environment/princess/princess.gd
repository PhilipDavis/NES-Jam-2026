extends CharacterBody2D
class_name Princess

@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var heart_animation: AnimatedSprite2D = $Visuals/Heart

const JUMP_VELOCITY = -144.0

func _ready() -> void:
	heart_animation.visible = false
	play_animation('Kiss')

func play_animation(anim: String) -> void:
	sprite.stop()
	sprite.play(anim)

func play_heart_animation() -> void:
	heart_animation.show()
	heart_animation.play('Love')
	await heart_animation.animation_finished
	heart_animation.hide()

func _physics_process(delta: float) -> void:
		# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	move_and_slide()
