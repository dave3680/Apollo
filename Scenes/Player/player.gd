extends CharacterBody3D

# 🏃 Movement Variables
@export var speed: float = 5.0
@export var acceleration: float = 10.0
@export var friction: float = 15.0
@export var jump_force: float = 7.5
@export var gravity: float = 20.0
@export var dash_speed: float = 15.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 1.0

# 🎯 Debugging Toggle
@export var debug_enabled: bool = false  # ✅ Toggle debugging in the inspector

# 🩸 Health Variables
@export var max_health: int = 100
var current_health: int
var invincible: bool = false
var invincibility_duration: float = 1.0

@export var camera: Camera3D  # Assign in the Inspector

# ⚔️ Attack Variables
@export var melee_damage: int = 25
@export var attack_cooldown: float = 0.5
@export var attack_duration: float = 0.2  # How long the attack lasts
@export var projectile_scene: PackedScene  # Assign Projectile.tscn in the Inspector

var attack_timer := 0.0
var is_attacking := false

# Movement States
var direction := Vector3.ZERO
var velocity_y := 0.0
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0

# References
@onready var melee_hitbox = $MeleeAttack  # Area3D with a CollisionShape
@onready var attack_timer_node = $AttackTimer  # Optional timer to limit attack spam
@onready var muzzle = $Muzzle  # Set a Marker3D for ranged attack origin
@onready var attack_particles = $MeleeAttack/AttackParticles  # ✅ Reference the particles


func _ready():
	current_health = max_health
	melee_hitbox.monitoring = false  
	melee_hitbox.monitorable = false  
	melee_hitbox.hide()  # ✅ Hide the hitbox initially

	_debug_log("✅ Player Ready! Health:", str(current_health))


func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity_y -= gravity * delta

	# Handle Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity_y = jump_force
		_debug_log("🛫 Player Jumped!")

	# Handle Dashing
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown + dash_duration
		_debug_log("⚡ Player Dashing!")

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			_debug_log("🏁 Dash Ended!")

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Movement Input
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z += 1
		_debug_log("⬆️ Moving Forward")
	if Input.is_action_pressed("move_backward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

	# Convert Input Direction to World Direction (Relative to Camera)
	var cam_movement = Vector3.ZERO
	if camera:
		var cam_basis = camera.global_transform.basis
		var forward = -cam_basis.z
		var right = cam_basis.x
		cam_movement = (right * input_dir.x) + (forward * input_dir.z)
		cam_movement.y = 0  # Ignore vertical movement

		if cam_movement.length() > 0:
			cam_movement = cam_movement.normalized()

		direction = cam_movement * (dash_speed if is_dashing else speed)

		# 🔄 **8-Directional Snapping**
		if cam_movement.length() > 0:
			var angles = [
				Vector3(1, 0, 0),  # Right
				Vector3(1, 0, 1),  # Top-Right
				Vector3(0, 0, 1),  # Forward
				Vector3(-1, 0, 1), # Top-Left
				Vector3(-1, 0, 0), # Left
				Vector3(-1, 0, -1),# Bottom-Left
				Vector3(0, 0, -1), # Backward
				Vector3(1, 0, -1)  # Bottom-Right
			]

			var best_angle = angles[0]
			var best_dot = -1.0
			for angle in angles:
				var dot = cam_movement.dot(angle.normalized())
				if dot > best_dot:
					best_dot = dot
					best_angle = angle

			var target_rotation = global_transform.looking_at(global_transform.origin + best_angle, Vector3.UP)
			global_transform = target_rotation  # Instantly snap to the best direction

	# Apply velocity
	velocity.x = direction.x
	velocity.z = direction.z
	velocity.y = velocity_y

	if input_dir == Vector3.ZERO:
		direction = Vector3.ZERO  # Stop movement instantly

	move_and_slide()

	# Call Debug Process (Only Runs When Debug Mode is Enabled)
	_debug_process(cam_movement)

func _debug_process(cam_movement):
	if not debug_enabled:
		return  # ✅ If debugging is off, this function does nothing!

	print("\n📌 DEBUG INFO ======================")
	print("🎯 Player Moving: " + str(cam_movement))
	print("🧭 Facing Rotation: " + str(global_transform.basis.get_euler()))

func _input(event):
	if event.is_action_pressed("attack"):
		perform_melee_attack()
	
	if event.is_action_pressed("shoot"):
		shoot_projectile()

# 🗡️ Melee Attack System
var can_attack := true  # ✅ Prevent multiple hits per attack

func perform_melee_attack():
	if is_attacking or not can_attack:  # ✅ Prevent repeated attacks
		return  

	_debug_log("🗡️ Player Attacking!")

	is_attacking = true
	can_attack = false  # ✅ Disable further attacks until cooldown resets

	melee_hitbox.monitoring = true  
	melee_hitbox.monitorable = true  
	melee_hitbox.show()  

	# ✅ Play the particle effect
	if attack_particles:
		attack_particles.restart()  # Ensures it resets every time
		attack_particles.emitting = true  

	# ✅ Ensure attack hitbox exists only briefly
	await get_tree().create_timer(attack_duration).timeout

	melee_hitbox.monitoring = false  
	melee_hitbox.monitorable = false  
	melee_hitbox.hide()

	is_attacking = false

	# ✅ Short delay before another attack is allowed
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true  # ✅ Allow the next attack





func shoot_projectile():
	if attack_timer > 0:
		return

	var projectile = projectile_scene.instantiate()
	projectile.global_transform = muzzle.global_transform  # Fires from the muzzle point
	get_parent().add_child(projectile)

	_debug_log("🏹 Player Fired Projectile!")
	attack_timer = attack_cooldown

	if attack_timer_node:
		attack_timer_node.start(attack_cooldown)

# 🔧 Debug Print Function (Only Logs if Debug is Enabled)
func _debug_log(message, extra_info = ""):
	if debug_enabled:
		print(message, extra_info)

# 🩸 Damage System
func take_damage(amount: int):
	if invincible:
		return

	current_health -= amount
	_debug_log("💔 Player took damage! Health:", str(current_health))

	if current_health <= 0:
		die()
		return

	invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	invincible = false

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	_debug_log("💖 Player healed! Health:", str(current_health))

func die():
	_debug_log("☠️ Player Died!")
	queue_free()

# 🗡️ Handle Melee Attack Hits
var attacked_enemies = []  # ✅ Track which enemies have already been hit

func _on_melee_attack_body_entered(body):
	if body.is_in_group("enemy") and can_attack:  # ✅ Ensure only one hit per attack
		_debug_log("💥 Hit Enemy: " + body.name)

		if body.has_method("take_damage"):
			body.take_damage(melee_damage)
			_debug_log("✅ Damage Applied: " + str(melee_damage))

		# ✅ Immediately disable the hitbox to prevent further detections
		melee_hitbox.monitoring = false  
		melee_hitbox.monitorable = false  
		melee_hitbox.hide()
