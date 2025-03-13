extends CharacterBody3D

# Movement Variables
@export var speed: float = 7.0                      # Base movement speed when walking
@export var acceleration: float = 50.0              # Rate at which the character accelerates
@export var friction: float = 50.0                  # Rate at which the character decelerates when no input is given
@export var jump_force: float = 7.5                 # Vertical force applied when jumping
@export var gravity: float = 20.0                   # Gravity applied to the character when airborne
@export var dash_speed: float = 15.0                # Movement speed during a dash
@export var dash_duration: float = 0.1              # How long a dash lasts
@export var dash_cooldown: float = 1.0              # Cooldown period between dashes

# Debug Toggle
@export var debug_enabled: bool = false

# Health Variables
@export var max_health: int = 100
var current_health: int
var invincible: bool = false
@export var invincibility_duration: float = 1.0     # Duration of invincibility after taking damage

@export var camera: Camera3D

# Attack Variables
@export var melee_damage: int = 25
@export var attack_cooldown: float = 0.5
@export var attack_duration: float = 0.2            # Duration that the melee hitbox is active
@export var projectile_scene: PackedScene

var is_attacking: bool = false
var can_attack: bool = true
var can_shoot: bool = true

# Movement States
var is_dashing: bool = false
var dash_timer: float = 0.0                         # Time remaining for the current dash
var dash_cooldown_timer: float = 0.0                # Time remaining for dash cooldown
var current_speed: float = 0.0
var move_direction: Vector3 = Vector3.ZERO

# Node References
@onready var melee_hitbox = $MeleeAttack
@onready var muzzle = $Muzzle
@onready var attack_particles = $MeleeAttack/AttackParticles


# Called when the node is added to the scene.
# Initializes health and disables the melee hitbox.
func _ready():
	current_health = max_health
	melee_hitbox.monitoring = false
	melee_hitbox.monitorable = false
	melee_hitbox.hide()
	_debug_log("Player Ready! Health:", str(current_health))

# Main physics loop that updates every frame.
# Handles gravity, jumping, dashing, movement input,
# smooth acceleration/deceleration, and rotation snapping.
func _physics_process(delta):
	# Gravity & Jump
	if is_on_floor():
		velocity.y = 0                           # Reset vertical velocity when grounded
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force              # Apply jump force
			_debug_log("Player Jumped!")
	else:
		velocity.y -= gravity * delta              # Apply gravity when in the air

	# Dashing
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown + dash_duration
		_debug_log("Player Dashing!")
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			_debug_log("Dash Ended!")
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Movement Input
	var input_dir = Vector3(
		float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
		0,
		float(Input.is_action_pressed("move_forward")) - float(Input.is_action_pressed("move_backward"))
	)

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		# Convert input direction to world space (relative to camera)
		if camera:
			var cam_basis = camera.global_transform.basis
			var forward = -cam_basis.z
			var right = cam_basis.x
			move_direction = ((right * input_dir.x) + (forward * input_dir.z)).normalized()

			# 8-Directional Snapping
			if move_direction.length() > 0:
				var angles = [
					Vector3(1, 0, 0),   # Right
					Vector3(1, 0, 1),   # Top-Right
					Vector3(0, 0, 1),   # Forward
					Vector3(-1, 0, 1),  # Top-Left
					Vector3(-1, 0, 0),  # Left
					Vector3(-1, 0, -1), # Bottom-Left
					Vector3(0, 0, -1),  # Backward
					Vector3(1, 0, -1)   # Bottom-Right
				]
				var best_angle = angles[0]
				var best_dot = -1.0
				for angle in angles:
					var dot = move_direction.dot(angle.normalized())
					if dot > best_dot:
						best_dot = dot
						best_angle = angle
				var target_rotation = global_transform.looking_at(global_transform.origin + best_angle, Vector3.UP)
				global_transform = target_rotation

		# Determine target speed (dash or normal)
		var target_speed = (dash_speed if is_dashing else speed)
		# Smoothly accelerate current_speed toward target_speed
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		# No input: decelerate using friction (keeping the last move_direction)
		current_speed = move_toward(current_speed, 0, friction * delta)

	# Update horizontal velocity based on the current direction and speed
	velocity.x = move_direction.x * current_speed
	velocity.z = move_direction.z * current_speed

	move_and_slide()

func _input(event):
	if event.is_action_pressed("attack"):
		perform_melee_attack()
	elif event.is_action_pressed("shoot"):
		shoot_projectile()

func perform_melee_attack():
	# If already attacking or on cooldown, do nothing
	if is_attacking or not can_attack:
		return
		
	_debug_log("Player Attacking!")
	is_attacking = true
	can_attack = false

	# Activate the melee hitbox and show visual effects
	melee_hitbox.monitoring = true
	melee_hitbox.monitorable = true
	melee_hitbox.show()
	if attack_particles:
		attack_particles.restart()
		attack_particles.emitting = true

	# Keep the hitbox active for the attack duration
	await get_tree().create_timer(attack_duration).timeout
	melee_hitbox.monitoring = false
	melee_hitbox.monitorable = false
	melee_hitbox.hide()
	is_attacking = false

	# Wait for the cooldown before allowing another attack
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func shoot_projectile():
	# If on cooldown, do nothing
	if not can_shoot:
		return

	can_shoot = false

	# Spawn a new projectile at the muzzle position
	var projectile = projectile_scene.instantiate()
	projectile.global_transform = muzzle.global_transform
	get_parent().add_child(projectile)
	_debug_log("Player Fired Projectile!")

	# Wait for cooldown before allowing another shot
	await get_tree().create_timer(attack_cooldown).timeout
	can_shoot = true

func take_damage(amount: int):
	# Ignore damage if currently invincible
	if invincible:
		return

	current_health -= amount
	_debug_log("Player took damage! Health:", str(current_health))

	# If health drops to zero, trigger death
	if current_health <= 0:
		die()
		return

	# Activate temporary invincibility
	invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	invincible = false


func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	_debug_log("Player healed! Health:", str(current_health))

func die():
	_debug_log("Player Died!")
	queue_free()

func _debug_log(message, extra_info = ""):
	if debug_enabled:
		print(message, extra_info)

func _on_melee_attack_body_entered(body):
	# Check if the collided body is an enemy and if we are allowed to attack
	if body.is_in_group("enemy") and can_attack:
		_debug_log("Hit Enemy: " + body.name)

		# If the enemy has a take_damage method, apply melee damage
		if body.has_method("take_damage"):
			body.take_damage(melee_damage)
			_debug_log("Damage Applied: " + str(melee_damage))

		# Immediately disable the melee hitbox to prevent multiple hits
		melee_hitbox.monitoring = false
		melee_hitbox.monitorable = false
		melee_hitbox.hide()
