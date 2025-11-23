extends Area2D

# EXPORT VARS: Change these in the Inspector for each zone!
# Zoom 0.5 = View is 2x wider (Zoomed Out)
# Zoom 2.0 = View is 2x closer (Zoomed In)
@export var target_zoom: Vector2 = Vector2(0.5, 0.5) 
@export var transition_duration: float = 1.5

# We store the original zoom so we can reset it later
var default_zoom: Vector2 = Vector2.UP # Starts empty

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var cam = body.find_child("Camera2D")
		if cam:
			# 1. Save the current zoom (so we know what to go back to)
			default_zoom = cam.zoom
			
			# 2. Create a Tween (Animation)
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
			# 3. Animate the 'zoom' property to the new target
			tween.tween_property(cam, "zoom", target_zoom, transition_duration)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		var cam = body.find_child("Camera2D")
		if cam:
			# Animate back to the original zoom
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(cam, "zoom", default_zoom, transition_duration)
