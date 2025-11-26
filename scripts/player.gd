extends CharacterBody2D

@onready var player: AnimatedSprite2D = $AnimatedSprite2D
@onready var stand_shape: CollisionShape2D = $CollisionShape2D
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var head_check: RayCast2D = $RayCast2D
@onready var grapple_line: Line2D = $GrappleLine


# GENERAL MOVEMENT SETTINGS
const SPEED: float = 1000.0        
const ACCELERATION: float = 2000.0
const FRICTION: float = 2200.0    
const GRAVITY: float = 4000.0     
const JUMP_VELOCITY: float = -2300.0 

# WALL MECHANICS
const CLIMB_SPEED: float = 1350.0       
const CLIMB_ACCELERATION: float = 3000.0 
const WALL_JUMP_VELOCITY: float = -3000.0
const WALL_JUMP_PUSHBACK: float = 2250.0  

# GRAPPLE MECHANICS
const GRAPPLE_SPEED: float = 6750.0 
const GRAPPLE_FLING: float = 2700.0    

# SLIDE MECHANICS
const SLIDE_SPEED: float = 3000.0      
const SLIDE_FRICTION: float = 2000.0   
const SLIDE_JUMP_VELOCITY: float = -3600.0 
const SLIDE_STOP_THRESHOLD: float = 200.0 

# GRAPPLE MEcHANICS
var current_grapple_target: Area2D = null
var is_grappling: bool = false
var is_sliding: bool = false

var facingRight: bool = false

var respawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	respawn_position = global_position
	
	floor_snap_length = 80.0 
	floor_stop_on_slope = true
	
	var range_node = find_child("Range")
	if range_node and range_node is Area2D:
		var overlaps = range_node.get_overlapping_areas()
		for area in overlaps:
			if area.is_in_group("grapple_points"):
				current_grapple_target = area
				area.modulate = Color.GREEN

func _physics_process(delta: float) -> void:
	if is_grappling:
		_process_grapple_movement(delta)
		if velocity.x != 0:
			facingRight = velocity.x > 0
			
		if facingRight:
			if player.animation != "grappleRight": player.play("grappleRight")
		else:
			if player.animation != "grappleLeft": player.play("grappleLeft")
		
		move_and_slide()
		return
		
	if is_sliding:
		if player.animation != "slideLeft" and not facingRight:
			player.play("slideLeft")
		if player.animation != "slideRight" and facingRight:
			player.play("slideRight")
		_process_slide(delta)
		move_and_slide()
		return
	
	if Input.is_action_just_pressed("grapple") and current_grapple_target != null:
		start_grapple()
		return
	
	if Input.is_action_just_pressed("slide") and is_on_floor():
		start_slide()
		return
	
	
	var is_climbing = false
	if is_touching_climbable_wall() and Input.is_action_pressed("climb"):
		is_climbing = true
		velocity.y = move_toward(velocity.y, -CLIMB_SPEED, CLIMB_ACCELERATION * delta)
		velocity.x = -get_wall_normal().x * 10.0
		
	else:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			facingRight = direction > 0
			velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSHBACK
			facingRight = get_wall_normal().x > 0
	
	if velocity.x == 0:
		if facingRight and player.animation != "idleRight":
			player.play("idleRight")
		if !facingRight and player.animation != "idleLeft":
			player.play("idleLeft")
			
	elif is_on_floor() and not is_climbing:
		if facingRight and player.animation != "runRight":
			player.play("runRight")
		if !facingRight and player.animation != "runLeft":
			player.play("runLeft")
			
	elif is_climbing:
		if facingRight and player.animation != "climbRight":
			player.play("climbRight")
		if !facingRight and player.animation != "climbLeft":
			player.play("climbLeft")

	if velocity.y != 0.0 and not is_on_wall():
		if facingRight and player.animation != "climbRight":
			player.play("climbRight")
		if !facingRight and player.animation != "climbLeft":
			player.play("climbLeft")
			
	move_and_slide()


# HELPER FUNCTIONS 

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
	reset_state()

	global_position = respawn_position

	var cam = find_child("Camera2D")
	if cam and cam is Camera2D:
		cam.reset_smoothing()

func reset_state() -> void:

	is_sliding = false
	is_grappling = false
	velocity = Vector2.ZERO
	current_grapple_target = null
	
	stand_shape.set_deferred("disabled", false)
	slide_shape.set_deferred("disabled", true)

# GRAPPLE FUNCTIONS
func start_grapple() -> void:
	is_grappling = true
	velocity = Vector2.ZERO
	
	grapple_line.visible = true 
	
	grapple_line.clear_points()
	grapple_line.add_point(Vector2.ZERO)
	grapple_line.add_point(to_local(current_grapple_target.global_position))

func _process_grapple_movement(delta: float) -> void:
	if current_grapple_target == null:
		is_grappling = false
		grapple_line.visible = false
		return

	if grapple_line.points.size() >= 2:
		grapple_line.set_point_position(1, to_local(current_grapple_target.global_position))

	var direction = global_position.direction_to(current_grapple_target.global_position)
	var distance = global_position.distance_to(current_grapple_target.global_position)

	velocity = direction * GRAPPLE_SPEED

	if distance < 20.0 or distance < (GRAPPLE_SPEED * delta):
		finish_grapple(direction)

func finish_grapple(direction: Vector2) -> void:
	is_grappling = false
	velocity = direction * GRAPPLE_FLING
	
	grapple_line.visible = false

func _on_range_area_entered(area: Area2D) -> void:
	if area.is_in_group("grapple_points"):
		current_grapple_target = area
		area.modulate = Color.GREEN 

func _on_range_area_exited(area: Area2D) -> void:
	if area == current_grapple_target:
		current_grapple_target = null
		area.modulate = Color.WHITE

# SLIDE FUNCTIONS

func start_slide() -> void:
	is_sliding = true
	stand_shape.set_deferred("disabled", true)
	slide_shape.set_deferred("disabled", false)
	
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		velocity.x = input_dir * SLIDE_SPEED
		facingRight = input_dir > 0
	elif abs(velocity.x) > 10.0:
		velocity.x = sign(velocity.x) * SLIDE_SPEED
	else:
		velocity.x = 0

func _process_slide(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if not head_check.is_colliding():
			velocity.y = SLIDE_JUMP_VELOCITY
			finish_slide()
			return 

	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:

		if velocity.x != 0 and sign(input_dir) != sign(velocity.x):
			if not head_check.is_colliding():
				finish_slide()
				return
	
	if is_on_wall():
		if not head_check.is_colliding():
			finish_slide()
			return

	velocity.x = move_toward(velocity.x, 0, SLIDE_FRICTION * delta)
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if abs(velocity.x) < SLIDE_STOP_THRESHOLD:
		if not Input.is_action_pressed("slide"):
			finish_slide()

func finish_slide() -> void:
	if head_check.is_colliding():
		if velocity.x == 0: 
			velocity.x = 100 * (1 if facingRight else -1)
		return 
		
	is_sliding = false
	stand_shape.set_deferred("disabled", false)
	slide_shape.set_deferred("disabled", true)
