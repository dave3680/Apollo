extends Camera3D

@export var target: CharacterBody3D  # Assign the Player in Inspector
@export var smooth_speed: float = 3.0  # Adjust for smooth following
@export var dead_zone_size: Vector2 = Vector2(3.0, 3.0)  # Dead zone before camera moves
@export var dead_zone_damping: float = 0.1  # Smooths out minor camera movement
@export var debug_enabled: bool = false  # ✅ Toggle debug messages in Inspector

var initial_offset: Vector3  # Stores the camera's correct offset
var is_following := false  # Flag to prevent continuous following

func _ready():
	if not target:
		_debug_log("❌ ERROR: Target not assigned!")
		return

	# ✅ Ensure offset is stored at the start & does not reset every frame
	initial_offset = global_transform.origin - target.global_transform.origin
	_debug_log("✅ Camera Ready! Initial offset:", initial_offset)

func _process(delta):
	if not target:
		return

	# Get world positions
	var player_pos = target.global_transform.origin
	var camera_pos = global_transform.origin

	# ✅ Convert player movement into camera-relative space
	var cam_basis = global_transform.basis
	var cam_right = cam_basis.x.normalized()  # Camera's right direction
	var cam_forward = -cam_basis.z.normalized()  # Camera's forward direction

	# ✅ Compute offsets in correct space
	var relative_offset_x = cam_right.dot(player_pos - camera_pos)
	var relative_offset_z = cam_forward.dot(player_pos - camera_pos)
	var relative_offset = Vector2(relative_offset_x, relative_offset_z)

	# Define dead zone boundaries
	var move_x = abs(relative_offset.x) > dead_zone_size.x
	var move_z = abs(relative_offset.y) > dead_zone_size.y

	if move_x or move_z:
		if not is_following:
			_debug_log("🚨 Player LEFT the Dead Zone! Enabling Camera Movement...")
			is_following = true  # Enable movement only once player exits dead zone

		# ✅ Fix: Ensure camera smoothly follows without locking depth
		var desired_position = player_pos + initial_offset
		global_transform.origin = global_transform.origin.lerp(desired_position, smooth_speed * delta * dead_zone_damping)

	elif is_following:
		_debug_log("✅ Player MOVED BACK INTO Dead Zone! Stopping Camera Movement...")
		is_following = false  # Stop following when player re-enters the dead zone

	# Call debug processing separately
	_debug_process(player_pos, camera_pos, relative_offset)

# 🔍 **Dedicated Debug Process**
func _debug_process(player_pos, camera_pos, relative_offset):
	if not debug_enabled:
		return  # ✅ If debugging is off, this function does nothing!

	# Debugging Info (Only prints if debug mode is enabled)
	print("\n📌 DEBUG INFO ======================")
	print("🔍 Player World Position:", player_pos)
	print("📸 Camera World Position:", camera_pos)
	print("📐 Initial Offset:", initial_offset)
	print("📏 Offset in Camera Space:", relative_offset)
	print("🎯 Dead Zone Size:", dead_zone_size)

# 🔧 **Debug Print Function (Only Prints if Debug is Enabled)**
func _debug_log(message, value = null):
	if debug_enabled:
		if value != null:
			print(message, " ", value)
		else:
			print(message)
