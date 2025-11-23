extends Area2D

@onready var fixed_camera: Camera2D = $Camera2D

func _ready() -> void:
	# Ensure the collision mask detects the player!
	# (Make sure "Monitoring" is ON in the Inspector)
	
	# Connect signals via code (or do it via editor if you prefer)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Ensure camera is off by default
	fixed_camera.enabled = false

func _on_body_entered(body: Node2D) -> void:
	# Check if it's the player (assuming your player is named "Player" or in a group)
	if body.name == "Player" or body.is_in_group("player"):
		fixed_camera.enabled = true
		fixed_camera.make_current() # Force the switch

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		fixed_camera.enabled = false
		# Godot will automatically fall back to the Player's camera
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
