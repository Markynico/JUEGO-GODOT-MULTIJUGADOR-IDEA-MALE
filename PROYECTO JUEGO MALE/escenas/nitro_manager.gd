class_name NitroManager
extends Node


signal nitro_activado
signal nitro_desactivado
signal valor_nitro_cambio(valor : float)

@export var body : Player

@export var nitro_inicial : float = 100
@export var consumo_nitro : float = 35.0 # unidades por segundo
@export var recarga_nitro : float = 1.5 # unidades por segundo
var nitro_actual : float
var ultimo_valor_nitro : float
var nitro_activo : bool = false

func _ready() -> void:
	nitro_actual = nitro_inicial


func _input(event: InputEvent) -> void:
	if not body.is_multiplayer_authority():
		return
	if Input.is_action_pressed("shift") and nitro_actual > 0:
		activar_nitro()
	if Input.is_action_just_released("shift"):
		desactivar_nitro()

func _physics_process(delta: float) -> void:
	if not body.is_multiplayer_authority():
		return
	#if not nitro_activado:
		#return
	procesar_nitro(delta)



func activar_nitro():
	if nitro_activo:
		return
	print("activar nitro")
	nitro_activo = true
	nitro_activado.emit()


func desactivar_nitro():
	if not nitro_activo:
		return
	nitro_activo = false
	nitro_desactivado.emit()
	print("desactivar nitro")
	#set_physics_process(false)


func procesar_nitro(delta):
	ultimo_valor_nitro = nitro_actual
	if nitro_activo:
		nitro_actual -= consumo_nitro * delta
	else:
		nitro_actual += recarga_nitro * delta #capaz quitamos la recarga de nitro
	nitro_actual = clamp(nitro_actual, 0.0, 100.0)
	
	if ultimo_valor_nitro != nitro_actual:
		#cambio el valor
		valor_nitro_cambio.emit(nitro_actual) #para avisarle por ejemplo al HUD q actualice el valor de la barra

	if nitro_actual <= 0:
		desactivar_nitro()
