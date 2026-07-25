@icon("res://2d/iconos_personalizados/camara_manager.png")
class_name CamarasManager
extends Node3D
#hago un manager centralizar donde se van a cambiar las camaras
#para cambiar entre camara jugador y camara espectando

@export var body : Player
@export var _camara_jugador : Camera3D
@export var _camara_espectador : CamaraLibre
@export var spring_arm_camara_jugador : CamaraPrincipalPlayer
@export var fov_minimo : float = 85
@export var fov_maximo_nitro : float = 120
var fov_objetivo : float #cuando activo el nitro el fov objetivo es el maximo y cuando lo desactivo es el minimo


#LO RELACIONADO A CAMBIO DE CAMARAS
enum CAMARAS {JUGADOR , ESPECTADOR}
@export var camara_activa : CAMARAS = CAMARAS.JUGADOR



func _ready() -> void:
	if not body.is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#_camara_espectador.current = true #esto dsp sacarlo para q no pise el estado real al iniciar
	_camara_jugador.current = true #esto dsp sacarlo para q no pise el estado real al iniciar
	fov_objetivo = fov_minimo
	#estas dos conexiones faltaban: el cambio de modo cambiaba el movimiento pero nunca la camara
	#van con el guard de authority porque la camara es cosa de cada jugador en su propia compu
	body.cambiar_a_modo_espectador.connect(_on_activar_camara_espectador)
	body.cambiar_a_modo_corredor.connect(_on_activar_camara_jugador)


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
	_camara_jugador.fov = move_toward(_camara_jugador.fov,fov_objetivo, 20 * delta)


func _on_activar_camara_jugador():
	_camara_jugador.current = true
	camara_activa = CAMARAS.JUGADOR
	_camara_espectador.desactivar_camara()
	spring_arm_camara_jugador.activar_camara()


func _on_activar_camara_espectador():
	_camara_espectador.current = true
	camara_activa = CAMARAS.ESPECTADOR
	spring_arm_camara_jugador.desactivar_camara()
	_camara_espectador.activar_camara()
	
