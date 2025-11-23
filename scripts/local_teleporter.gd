extends Area2D

# Assign the specific Marker2D you want to go to in the Inspector
@export var destination_node: Marker2D

func _ready() -> void:
	# Connect the signal automatically
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check for Player (assuming the root node is named "Player")
	if body.name == "Player":
		if destination_node:
			# 1. Teleport the player
			body.global_position = destination_node.global_position
			
			# 2. Reset Player State
			# This stops them from sliding/grappling *out* of the teleport
			if body.has_method("reset_state"):
				body.reset_state()
				
			# 3. Reset Camera Smoothing
			# Prevents the camera from "swooshing" across the map to the new spot
			var cam = body.find_child("Camera2D")
			if cam and cam is Camera2D:
				cam.reset_smoothing()
			
			# 4. UPDATE RESPAWN POINT (New Feature)
			# Now, if they fall into a pit later, they will respawn HERE
			if body.has_method("update_respawn_point"):
				body.update_respawn_point(destination_node.global_position)
				
		else:
			print("ERROR: No destination assigned for teleporter: ", name)
