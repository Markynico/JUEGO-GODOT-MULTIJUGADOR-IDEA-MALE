class_name CamaraPrincipalPlayer
extends SpringArm3D

@export var body : Player
@export var sens_mouse : float = 0.005
@export var zoom_out_maximo : float = 15
@export var zoom_out_minimo : float = 1.5
@export var activo : bool = true
var rotacion_inicial : Vector3

func _ready() -> void:
	rotacion_inicial = rotation



func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sens_mouse
		rotation.y = wrapf(rotation.y , 0.0, TAU) #TAU equivale a 360 grados
		
		rotation.x -= event.relative.y * sens_mouse
		rotation.x = clamp(rotation.x , -PI/2 , PI/4)

	if event.is_action_pressed("mouse_rueda_arriba"):
		spring_length -= 1 # o sino con un tween
		spring_length = clamp(spring_length , zoom_out_minimo , zoom_out_maximo)
	if event.is_action_pressed("mouse_rueda_abajo"):
		spring_length += 1
		spring_length = clamp(spring_length , zoom_out_minimo , zoom_out_maximo)


func desactivar_camara():
	activo = false
	rotation = rotacion_inicial

func activar_camara():
	activo = true
