extends Node3D

@export var light: OmniLight3D
@export var flicker_intensity: float = 0.2  # How much the light flickers
@export var flicker_speed: float = 10.0  # How fast the flicker changes

func _process(delta):
	if light:
		light.energy = 4.0 + randf_range(-flicker_intensity, flicker_intensity) * flicker_speed * delta
