@icon("res://2d/iconos_personalizados/icono_camara_custom.png")
extends Camera3D
class_name CamaraLibre

@export var velocidad_movimiento : float = 20.0
@export var sensibilidad_mouse : float = 0.002
@export var activo : bool = false #me parece q podria sacarlo
@export var marker_posicion : Marker3D

@export var escena_pelotita : PackedScene

@export var fuerza_disparo : float = 20.0

var move_target : Vector3 

var movimiento_y : float = 0.0
var movimiento_x : float = 0.0

var rotacion_inicial : Vector3
var posicion_inicial : Vector3

func _ready() -> void:
	#inicializo cositasss
	movimiento_y = rotation.y
	movimiento_x = rotation.x
	move_target = position
	rotacion_inicial = rotation
	posicion_inicial = position


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
	
	#probando meterle funcionalidad de dispara cosas desde la camara:
	if Input.is_action_just_pressed("click_izq"):
		var mouse = get_viewport().get_mouse_position()
		var origen = global_position
		var direccion = project_ray_normal(mouse)
		disparar_probando.rpc(origen, direccion) #hacer q todas las compus vean la pelotita q dispara la otra persona


@rpc("authority","reliable","call_local")
func disparar_probando(origen: Vector3, direccion: Vector3):
	var pelota = escena_pelotita.instantiate()
	get_tree().current_scene.add_child(pelota)

	pelota.global_position = origen
	pelota.linear_velocity = direccion * fuerza_disparo
	
	#var instancia_pelotita : RigidBody3D = escena_pelotita.instantiate()
	##print("CLICK IZQ")
	#get_tree().current_scene.add_child(instancia_pelotita)
	##posiciono con la cmara
	##instancia_pelotita.global_position = global_position
	#
	#var mouse = get_viewport().get_mouse_position()
#
	##var origen = project_ray_origin(mouse)
	#var origen = global_position_camara
	#var direccion = project_ray_normal(mouse)
#
	#instancia_pelotita.global_position = origen
	#
	#instancia_pelotita.linear_velocity = direccion * fuerza_disparo


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
	move_target = position #sino la camara sale volando hacia un target viejo
	movimiento_y = rotation.y
	movimiento_x = rotation.x
	set_process(true)

func desactivar_camara():
	activo = false
	set_process(false)
	rotation = rotacion_inicial
	#el marker es opcional (en la escena del personaje no esta seteado y esto crasheaba con
	#un null), si no lo tenemos volvemos a la posicion que tenia la camara en la escena
	var posicion_reset : Vector3 = marker_posicion.position if marker_posicion else posicion_inicial
	position = posicion_reset
	move_target = posicion_reset
	movimiento_x = 0.0
	movimiento_y = 0.0
