extends CharacterBody3D

@export var speed: float = 3.0
@export var health: int = 100
@export var debug_enabled: bool = true  # Set to true to enable debug logs

var player: Node3D = null
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	# Find the player in the scene
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		print_debug("⚠️ No player found in the scene! Make sure the player is in the 'player' group.")

	# Configure NavigationAgent3D
	nav_agent.path_desired_distance = 0.5  # Stop close to the target
	nav_agent.target_desired_distance = 0.5
	nav_agent.avoidance_enabled = true  # Enable obstacle avoidance

	# Debug: Show initial state
	if debug_enabled:
		print_debug("✅ Enemy AI Initialized!")
		print_debug("   ➤ NavigationAgent3D Path Distance:", nav_agent.path_desired_distance)
		print_debug("   ➤ NavigationAgent3D Target Distance:", nav_agent.target_desired_distance)
		print_debug("   ➤ Avoidance Enabled:", nav_agent.avoidance_enabled)

func _process(delta):
	if player:
		# Set the player's position as the target
		nav_agent.set_target_position(player.global_position)

		# Debug: Show path status
		if debug_enabled:
			print_debug("🔄 Target Position Set:", player.global_position)
			print_debug("   ➤ Navigation Finished?:", nav_agent.is_navigation_finished())
			print_debug("   ➤ Current Global Position:", global_position)

		# Check if the path is valid before moving
		if nav_agent.is_navigation_finished():
			return  # Stop moving when close to the player

		var next_position = nav_agent.get_next_path_position()
		if debug_enabled:
			print_debug("   ➤ Next Path Position:", next_position)

		# Move towards the next position
		var direction = (next_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func take_damage(amount: int):
	health -= amount
	print_debug("💀 Enemy took", amount, "damage! Health:", health)

	if health <= 0:
		die()

func die():
	print_debug("☠️ Enemy Died!")
	queue_free()  # Remove enemy from scene
