class_name CamarasManager
extends Node3D
#hago un manager centralizar donde se van a cambiar las camaras
#para cambiar entre camara jugador y camara espectando

@export var body : Player
@export var camara_jugador : Camera3D
@export var fov_minimo : float = 85
@export var fov_maximo_nitro : float = 120
var fov_objetivo : float #cuando activo el nitro el fov objetivo es el maximo y cuando lo desactivo es el minimo


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not body.is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camara_jugador.current = true
	fov_objetivo = fov_minimo


func _physics_process(delta: float) -> void:
	if not body.is_multiplayer_authority():
		return
	actualizar_fov(delta)


func _input(event: InputEvent) -> void:
	if not body.is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


#func actualizar_fov_camara(valor_nitro : float): #se ejecuta con la signal del NITRO MANAGER
	#var fov_objetivo = remap(valor_nitro, 100.0 , 0.0, fov_minimo, fov_maximo_nitro)
	#camara_jugador.fov = fov_objetivo


func _on_nitro_activado():
	fov_objetivo = fov_maximo_nitro

func _on_nitro_desactivado():
	#set_physics_process(false)
	fov_objetivo = fov_minimo


func actualizar_fov(delta):
	camara_jugador.fov = move_toward(camara_jugador.fov,fov_objetivo, 20 * delta)
