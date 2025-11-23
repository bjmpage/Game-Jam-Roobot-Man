extends CharacterBody2D

@onready var player: Sprite2D = $Sprite2D
@onready var stand_shape: CollisionShape2D = $CollisionShape2D
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var head_check: RayCast2D = $RayCast2D

# GENERAL MOVEMENT SETTINGS
const SPEED: float = 1000.0        # (600 * 4.5)
const ACCELERATION: float = 2000.0 # (1200 * 4.5)
const FRICTION: float = 2200.0     # (1500 * 4.5)
const GRAVITY: float = 4000.0      # (1200 * 4.5)
const JUMP_VELOCITY: float = -2300.0 # (-600 * 4.5)

# WALL MECHANICS
const CLIMB_SPEED: float = 1350.0        # (300 * 4.5)
const CLIMB_ACCELERATION: float = 3000.0 # (800 * 4.5)
const WALL_JUMP_VELOCITY: float = -3000.0 # (-800 * 4.5)
const WALL_JUMP_PUSHBACK: float = 2250.0  # (500 * 4.5)

# GRAPPLE MECHANICS
const GRAPPLE_SPEED: float = 6750.0      # (1500 * 4.5)
const GRAPPLE_FLING: float = 2700.0      # (600 * 4.5)

# SLIDE MECHANICS
const SLIDE_SPEED: float = 3000.0        # (800 * 4.5)
const SLIDE_FRICTION: float = 2000.0     # (400 * 4.5)
const SLIDE_JUMP_VELOCITY: float = -3600.0 # (-800 * 4.5)
const SLIDE_STOP_THRESHOLD: float = 200.0 # Adjusted for Scale

# VARIABLES
var current_grapple_target: Area2D = null
var is_grappling: bool = false
var is_sliding: bool = false

# RESPAWN SYSTEM
var respawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 1. Set initial respawn point
	respawn_position = global_position
	
	# 2. CRITICAL FIX FOR GIANTS:
	# Prevents jittering and sticking on slopes
	floor_snap_length = 80.0 
	floor_stop_on_slope = true
	
	# 3. CRITICAL FIX FOR GRAPPLE SPAWN:
	# We look for the "Range" node and check if we are ALREADY touching a hook
	# Make sure your sensor node is named "Range" or update the string below
	var range_node = find_child("Range")
	if range_node and range_node is Area2D:
		var overlaps = range_node.get_overlapping_areas()
		for area in overlaps:
			if area.is_in_group("grapple_points"):
				current_grapple_target = area
				area.modulate = Color.GREEN
				print("Spawned inside grapple point!")

func _physics_process(delta: float) -> void:
	# 1. SPECIAL STATES (Grapple/Slide)
	if is_grappling:
		_process_grapple_movement(delta)
		move_and_slide()
		return
		
	if is_sliding:
		_process_slide(delta)
		move_and_slide()
		return
	
	# 2. INPUT CHECKS (Start States)
	if Input.is_action_just_pressed("grapple") and current_grapple_target != null:
		start_grapple()
		return
	
	if Input.is_action_just_pressed("slide") and is_on_floor():
		start_slide()
		return
	
	
	# 3. WALL CLIMB LOGIC
	var is_climbing = false
	if is_touching_climbable_wall() and Input.is_action_pressed("climb"):
		is_climbing = true
		velocity.y = move_toward(velocity.y, -CLIMB_SPEED, CLIMB_ACCELERATION * delta)
		velocity.x = -get_wall_normal().x * 10.0
		
	else:
		# 4. NORMAL GRAVITY & MOVEMENT
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			player.flip_h = direction > 0
			velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# 5. JUMP LOGIC
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSHBACK
			player.flip_h = get_wall_normal().x > 0

	move_and_slide()


# --- HELPER FUNCTIONS ---

func is_touching_climbable_wall() -> bool:
	if not is_on_wall():
		return false
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("climbable"):
			return true
	return false

func update_respawn_point(new_pos: Vector2) -> void:
	respawn_position = new_pos
	print("Checkpoint updated!")

func respawn() -> void:
	# 1. Reset Physics State
	reset_state()
	
	# 2. Move to last safe spot
	global_position = respawn_position
	
	# 3. Reset Camera Smoothing
	var cam = find_child("Camera2D")
	if cam and cam is Camera2D:
		cam.reset_smoothing()

func reset_state() -> void:
	# Resets all movement states
	is_sliding = false
	is_grappling = false
	velocity = Vector2.ZERO
	current_grapple_target = null
	
	stand_shape.set_deferred("disabled", false)
	slide_shape.set_deferred("disabled", true)

# --- GRAPPLE FUNCTIONS ---
func start_grapple() -> void:
	is_grappling = true
	velocity = Vector2.ZERO 

func _process_grapple_movement(delta: float) -> void:
	if current_grapple_target == null:
		is_grappling = false
		return

	var direction = global_position.direction_to(current_grapple_target.global_position)
	var distance = global_position.distance_to(current_grapple_target.global_position)

	velocity = direction * GRAPPLE_SPEED

	if distance < 20.0 or distance < (GRAPPLE_SPEED * delta):
		finish_grapple(direction)

func finish_grapple(direction: Vector2) -> void:
	is_grappling = false
	velocity = direction * GRAPPLE_FLING

func _on_range_area_entered(area: Area2D) -> void:
	if area.is_in_group("grapple_points"):
		current_grapple_target = area
		area.modulate = Color.GREEN 

func _on_range_area_exited(area: Area2D) -> void:
	if area == current_grapple_target:
		current_grapple_target = null
		area.modulate = Color.WHITE

# --- SLIDE FUNCTIONS ---

func start_slide() -> void:
	is_sliding = true
	stand_shape.set_deferred("disabled", true)
	slide_shape.set_deferred("disabled", false)
	
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		velocity.x = input_dir * SLIDE_SPEED
		player.flip_h = input_dir > 0
	elif abs(velocity.x) > 10.0:
		velocity.x = sign(velocity.x) * SLIDE_SPEED
	else:
		velocity.x = 0

func _process_slide(delta: float) -> void:
	# --- 1. CANCELLATION LOGIC ---
	
	# A. Jump Cancel
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if not head_check.is_colliding():
			velocity.y = SLIDE_JUMP_VELOCITY
			finish_slide()
			return 

	# B. Opposite Input Cancel
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		# If pressing OPPOSITE direction to velocity, stand up immediately
		if velocity.x != 0 and sign(input_dir) != sign(velocity.x):
			if not head_check.is_colliding():
				finish_slide()
				return
	
	# C. Hit Wall Cancel (FIXES THE FREEZE)
	# If we hit a wall, stop sliding immediately.
	if is_on_wall():
		if not head_check.is_colliding():
			finish_slide()
			return

	# --- 2. PHYSICS ---
	velocity.x = move_toward(velocity.x, 0, SLIDE_FRICTION * delta)
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# --- 3. STOPPING CONDITION ---
	# Increased threshold to 200.0 to prevent drifting
	if abs(velocity.x) < SLIDE_STOP_THRESHOLD:
		# Only stand up if the player RELEASED the slide button
		if not Input.is_action_pressed("slide"):
			finish_slide()

func finish_slide() -> void:
	if head_check.is_colliding():
		# If we are stuck, give a little nudge
		if velocity.x == 0: 
			velocity.x = 100 * (1 if player.flip_h else -1)
		return 
		
	is_sliding = false
	stand_shape.set_deferred("disabled", false)
	slide_shape.set_deferred("disabled", true)
