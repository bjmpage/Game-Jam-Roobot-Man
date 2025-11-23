extends Node2D

@onready var camera_limits = $CameraLimits
@onready var player = $Player # Make sure this path is correct!

func _ready() -> void:
	# 1. Find the Player's Camera
	# We assume the camera is a direct child of the player named "Camera2D"
	var cam = player.find_child("Camera2D")
	
	if cam and camera_limits:
		# 2. Set the Camera Limits to match the ReferenceRect box
		cam.limit_left = camera_limits.position.x
		cam.limit_top = camera_limits.position.y
		cam.limit_right = camera_limits.position.x + camera_limits.size.x
		cam.limit_bottom = camera_limits.position.y + camera_limits.size.y
