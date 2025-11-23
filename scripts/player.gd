extends CharacterBody2D

@onready var player: Sprite2D = $Sprite2D
@onready var stand_shape: CollisionShape2D = $CollisionShape2D
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var head_check: RayCast2D = $RayCast2D

# GENERAL MOVEMENT SETTINGS
const SPEED: float = 1000.0
const ACCELERATION: float = 1300.0
const FRICTION: float = 1700.0
const GRAVITY: float = 1500.0
const JUMP_VELOCITY: float = -1100.0

# WALL MECHANICS
const CLIMB_SPEED: float = 300.0
const CLIMB_ACCELERATION = 800.0   # How fast we reach max speed
const WALL_JUMP_VELOCITY: float = -800.0
const WALL_JUMP_PUSHBACK: float = 500.0

# GRAPPLE MECHANICS
const GRAPPLE_SPEED: float = 1500.0
const GRAPPLE_FLING: float = 600.0

# SLIDE MECHANICS
const SLIDE_SPEED = 800.0
const SLIDE_FRICTION = 400.0
const SLIDE_JUMP_VELOCITY = -800.0

# VARIABLES
var current_grapple_target: Area2D = null
var is_grappling: bool = false
var is_sliding: bool = false


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
	# We use a variable to track if we are currently climbing this frame
	var is_climbing = false
	
	# Only climb if touching a climbable wall AND pressing the button
	if is_touching_climbable_wall() and Input.is_action_pressed("climb"):
		is_climbing = true
		
		# ACCELERATION: Speed up smoothly to max climb speed
		velocity.y = move_toward(velocity.y, -CLIMB_SPEED, CLIMB_ACCELERATION * delta)
		
		# STICK TO WALL force
		velocity.x = -get_wall_normal().x * 10.0
		
	else:
		# 4. NORMAL GRAVITY & MOVEMENT (Run only if NOT climbing)
		
		# A. Apply Gravity
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			
		# B. Horizontal Movement 
		# We put this here so it doesn't fight the "Stick to wall" force above
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			player.flip_h = direction > 0
			velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# 5. JUMP LOGIC (Overrides Gravity/Climb)
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			# Wall Jump
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
		# Check if the object has the group "climbable"
		if collision.get_collider().is_in_group("climbable"):
			return true
	return false

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
	# Check the area itself OR its parent (just in case)
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
	
	# 1. Swap Hitboxes
	stand_shape.set_deferred("disabled", true)
	slide_shape.set_deferred("disabled", false)
	
	# 2. DETERMINE MOVEMENT
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Priority A: Sliding in direction of key press
	if input_dir != 0:
		velocity.x = input_dir * SLIDE_SPEED
		player.flip_h = input_dir > 0
		
	# Priority B: Sliding with existing momentum (only if moving fast)
	elif abs(velocity.x) > 10.0:
		velocity.x = sign(velocity.x) * SLIDE_SPEED
		
	# Priority C: Stationary Crouch (No movement)
	else:
		velocity.x = 0

func _process_slide(delta: float) -> void:
	# --- 1. BOOST JUMP ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if not head_check.is_colliding():
			velocity.y = SLIDE_JUMP_VELOCITY
			finish_slide()
			return 

	# --- 2. PHYSICS ---
	velocity.x = move_toward(velocity.x, 0, SLIDE_FRICTION * delta)
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# --- 3. STOPPING CONDITION (Modified for Stationary) ---
	# If speed is low, we check if we should keep crouching or stand up
	if abs(velocity.x) < 50.0:
		# Only stand up if the player RELEASED the slide button
		# This allows you to stay crouched in place
		if not Input.is_action_pressed("slide"):
			finish_slide()

func finish_slide() -> void:
	# CRITICAL: Do not stand up if there is a ceiling!
	if head_check.is_colliding():
		# Force tiny movement if stuck?
		if velocity.x == 0: 
			velocity.x = 100 * (1 if player.flip_h else -1)
		return 

	is_sliding = false
	stand_shape.set_deferred("disabled", false)
	slide_shape.set_deferred("disabled", true)
