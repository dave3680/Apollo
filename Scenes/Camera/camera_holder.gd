extends Node3D  # CameraHolder should use this instead of Camera3D

@export var target: CharacterBody3D  # Assign the Player in Inspector
@export var smooth_speed: float = 5.0  # Adjust for how smooth the camera follows
@export var debug_enabled: bool = false  # ✅ Toggle debug messages in Inspector

var initial_offset: Vector3  # Stores the camera's correct offset

func _ready():
	if not target:
		print_debug("❌ ERROR: Target not assigned!")  # Only prints if debug is enabled
		return

	# Store the initial offset relative to the player
	initial_offset = global_transform.origin - target.global_transform.origin
	print_debug("✅ CameraHolder Ready! Initial Offset:", initial_offset)

func _process(delta):
	if not target:
		print_debug("⚠️ Warning: No target assigned to CameraHolder!")
		return

	# Compute the desired position (ignoring rotation)
	var desired_position = target.global_transform.origin + initial_offset
	var current_position = global_transform.origin

	# Debugging Statements
	if debug_enabled:  # ✅ FIX: Prevents debug spam when disabled
		print("\n📸 DEBUG: CameraHolder")
		print("🎯 Player Position:", target.global_transform.origin)
		print("📍 Current CameraHolder Position:", current_position)
		print("📏 Initial Offset:", initial_offset)
		print("🚀 Moving towards:", desired_position)

	# Smoothly move CameraHolder to follow the player
	global_transform.origin = global_transform.origin.lerp(desired_position, smooth_speed * delta)

	# Confirm movement
	if debug_enabled and global_transform.origin.distance_to(desired_position) < 0.1:
		print("✅ CameraHolder reached the target position!")

# 🔧 Debug Print Function (Now Works Properly)
func print_debug(message, value = null):
	if debug_enabled:  # ✅ FIX: Now it only prints if debug is enabled
		if value != null:
			print(message, " ", value)
		else:
			print(message)
