class_name CamarasManager
extends Node3D
#hago un manager centralizar donde se van a cambiar las camaras
#para cambiar entre camara jugador y camara espectando

@export var body : Player
@export var camara_jugador : Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not body.is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camara_jugador.current = true
	


func _input(event: InputEvent) -> void:
	if not body.is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
