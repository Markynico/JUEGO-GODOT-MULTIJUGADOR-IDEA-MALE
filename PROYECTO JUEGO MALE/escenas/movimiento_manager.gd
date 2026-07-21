class_name MovimientoManager
extends Node

@export var body : Player
@export var camara_jugador : Camera3D
@export var skin_jugador : Node3D
@export var aceleracion : float = 40.0
@export var desaceleracion : float = 70.0

enum ESTADOS {IDLE, CAMINAR, SALTANDO, INACTIVO}
var estado_actual : ESTADOS = ESTADOS.IDLE
var ultimo_estado : ESTADOS

@export var velocidad : float= 15
@export var velocidad_salto : float = 5.5



func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if not body.is_multiplayer_authority():
		return
	aplicar_gravedad(delta)
	var direction = calcular_direccion()
	rotar_personaje(direction, delta)
	procesar_estado_actual(direction, delta)
	body.move_and_slide()


func aplicar_gravedad(delta : float):
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta


func movimiento_wasd(direction : Vector3, delta : float):
	if direction:
		body.velocity.x = move_toward(body.velocity.x, direction.x * velocidad, aceleracion * delta)
		body.velocity.z = move_toward(body.velocity.z, direction.z * velocidad, aceleracion * delta)
	else:
		desacelerar_a_quieto(delta)


func desacelerar_a_quieto(delta : float):
	body.velocity.x = move_toward(body.velocity.x, 0, desaceleracion * delta)
	body.velocity.z = move_toward(body.velocity.z, 0, desaceleracion * delta)

func cambiar_de_estado(estado_nuevo : ESTADOS):
	if estado_actual==estado_nuevo:
		return
	ultimo_estado = estado_actual
	estado_actual = estado_nuevo
	matchear_animaciones() #todavia sin uso, lo dejo para mas adelante


func matchear_animaciones():
	return #lo dejo para mas adelante
	match estado_actual:
		ESTADOS.IDLE:
			body.ejecutar_animacion_idle.emit()
		ESTADOS.CAMINAR:
			body.ejecutar_animacion_caminar.emit()
		ESTADOS.SALTANDO:
			body.ejecutar_animacion_salto.emit()
		ESTADOS.INACTIVO:
			body.ejecutar_animacion_idle.emit()



func procesar_estado_actual(direccion : Vector3 , delta : float):
	match estado_actual:
		ESTADOS.IDLE:
			procesar_idle(direccion, delta)
		ESTADOS.CAMINAR:
			procesar_caminar(direccion, delta)
		ESTADOS.SALTANDO:
			procesar_saltando(direccion, delta)


func manejar_salto(): #me permite cambiar al estado saltando
	if Input.is_action_just_pressed("espacio") and body.is_on_floor():
		cambiar_de_estado(ESTADOS.SALTANDO)
		body.velocity.y = velocidad_salto

func procesar_idle(direccion : Vector3 , delta: float):
	manejar_salto()
	if direccion!= Vector3.ZERO:
		cambiar_de_estado(ESTADOS.CAMINAR)
	else:
		desacelerar_a_quieto(delta)


func procesar_saltando(direccion : Vector3, delta : float):
	movimiento_wasd(direccion, delta)
	if body.is_on_floor():
		if direccion== Vector3.ZERO:
			cambiar_de_estado(ESTADOS.IDLE)
		else:
			cambiar_de_estado(ESTADOS.CAMINAR)

func procesar_caminar(direccion : Vector3, delta: float):
	movimiento_wasd(direccion, delta)
	manejar_salto() #cuando salto, cambio de estado en esa funcion
	if direccion == Vector3.ZERO:
		cambiar_de_estado(ESTADOS.IDLE)


func rotar_personaje(direction : Vector3, delta : float):
	if estado_actual==ESTADOS.INACTIVO:
		return
	#PARA HACER QUE EL PJ GIRE EN DIRECCION DE DONDE SE QUIERE MOVER (VISUAL POR ESO SOLO EL MESH)
	if direction.length() > 0.01:
		var angulo_target = atan2(direction.x, direction.z)
		skin_jugador.rotation.y = lerp_angle(skin_jugador.rotation.y, angulo_target, 10 * delta)

func calcular_direccion():
	var input_dir := Input.get_vector("a", "d", "w", "s")
	var direction := (body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#PARA QUE SE MUEVA HACIA ADELANTE TENIENDO EN CUENTA LA DIRECCION DE LA CAMARA
	direction = direction.rotated(Vector3.UP, camara_jugador.global_rotation.y)
	return direction
