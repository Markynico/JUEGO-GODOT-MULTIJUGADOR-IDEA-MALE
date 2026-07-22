#@icon("res://assets-2d/iconos_custom/icono_camara_custom.png")
extends Camera3D
class_name CamaraLibre

@export var velocidad_movimiento : float = 20.0
@export var sensibilidad_mouse : float = 0.002
@export var activo : bool = false #me parece q podria sacarlo
@export var marker_posicion : Marker3D
var move_target : Vector3 

var movimiento_y : float = 0.0
var movimiento_x : float = 0.0

var rotacion_inicial : Vector3

func _ready() -> void:
	#inicializo cositasss
	movimiento_y = rotation.y
	movimiento_x = rotation.x
	move_target = position
	rotacion_inicial = rotation


func _input(event: InputEvent) -> void:
	#if not activo: #me parece que es mejor pasar a current pq sino esta variable se activa primero sin esperar la transicion
	#y da un mini delay de movimiento
	if not current:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
	#	movimiento de camara con el mouse
		movimiento_y -=event.relative.x * sensibilidad_mouse
		movimiento_x -=event.relative.y * sensibilidad_mouse
		
		movimiento_x = clamp(movimiento_x, deg_to_rad(-89), deg_to_rad(89))
		rotation.y = movimiento_y
		rotation.x = movimiento_x
		#rotate_y(-event.relative.x * sensibilidad_mouse)
		#camara.rotate_x(-event.relative.y * sensibilidad_mouse)
		#camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-89), deg_to_rad(89)) #para limitar la rotacion



func _process(delta: float) -> void: #en process anda MUCHISIMO mejor que en physic process, sin nada de jitter
	if not current:
		return
	var input_dir := Input.get_vector("a", "d", "w", "s")

	var mov_vertical := 0.0
	if Input.is_action_pressed("espacio"):
		mov_vertical += 1.0
	if Input.is_action_pressed("control"):
		mov_vertical -= 1.0

	var local_dir : = Vector3(input_dir.x, mov_vertical, input_dir.y)
	
	var direction := Vector3.ZERO
	direction = (transform.basis * local_dir).normalized()
	move_target += velocidad_movimiento * direction * delta #puedo sacarlo, depende que uso para el movimiento
	
	position = position.lerp(move_target,1.0 - exp(-10.0 * delta))
	#sera que tengo que resetear move_target?


func activar_camara():
	activo = true
	set_process(true)
	#rotation = rotacion_inicial
	#global_position = posicion_inicial

func desactivar_camara():
	activo = false
	set_process(false)
	rotation = rotacion_inicial
	position = marker_posicion.position
	move_target = marker_posicion.position
	movimiento_x = 0.0
	movimiento_y = 0.0
