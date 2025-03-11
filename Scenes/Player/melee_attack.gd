extends Area3D

@export var damage: int = 25

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		body.take_damage(damage)
