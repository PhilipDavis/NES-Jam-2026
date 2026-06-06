extends StaticBody2D

@onready var tutorial_label: RichTextLabel = %TutorialLabel2

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		tutorial_label.activate()
