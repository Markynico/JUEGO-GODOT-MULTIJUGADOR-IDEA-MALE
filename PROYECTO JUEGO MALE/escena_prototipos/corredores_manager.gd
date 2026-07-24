class_name CorredoresManager
extends Node


@onready var button_comenzar_juego: Button = %ButtonComenzarJuego
@onready var label_tiempo_corredores: Label = %LabelTiempoCorredores
@onready var timer_corredores: Timer = %TimerCorredores
@onready var timer_segundos: Timer = %TimerSegundos
@onready var equipos_manager: EquiposManager = %EquiposManager


var tiempo_x_ronda : int = 90
var tiempo_actual : int 
#var array_ya_corrieron : Array = []

var lista_corredores_rojo : Array
var lista_corredores_azul : Array

func _ready() -> void:
	tiempo_actual = tiempo_x_ronda
	button_comenzar_juego.hide()



func _on_timer_corredores_timeout() -> void:
	#esto va a sonar cuando terminen los 90 segundos
	#quiero reiniciar el segundero
	tiempo_actual = tiempo_x_ronda #reinicio
	timer_corredores.start() #le digo a este mismo timer q vuelva a arrancar
	#y ahora selecciono corredores
	seleccionar_corredores() #q me falta la logica todavia


func seleccionar_corredores():
	# Primero todos pasan a espectador
	for id in Global.instancia_jugadores.keys():
		Global.instancia_jugadores[id].cambiar_a_modo_espectador.emit()

	
	#if lista_corredores_rojo.is_empty(): #meti estos return pq daba error, parece q por algun motivo las listas están vacias
		#return
	#if lista_corredores_azul.is_empty():
		#return
	
	# Elegimos el siguiente rojo
	var corredor_rojo = lista_corredores_rojo.pop_front()
	lista_corredores_rojo.push_back(corredor_rojo)

	# Elegimos el siguiente azul
	var corredor_azul = lista_corredores_azul.pop_front()
	lista_corredores_azul.push_back(corredor_azul)

	# Los convertimos en corredores
	Global.instancia_jugadores[corredor_rojo].cambiar_a_modo_corredor.emit()
	Global.instancia_jugadores[corredor_azul].cambiar_a_modo_corredor.emit()

	print("Corredor rojo:", corredor_rojo)
	print("Corredor azul:", corredor_azul)
	
	


func _on_timer_segundos_timeout() -> void:
	tiempo_actual -= 1
	#y avisarle al label q cambie de numero
	#label_tiempo_corredores.text = "Siguiente corredor en: " + str(tiempo_actual)
	if tiempo_actual < 0:
		return
	sincronizar_tiempo.rpc(tiempo_actual) #para q todos los jugadores tengan el label actualizado con el mismo tiempo


@rpc("authority", "call_local")
func sincronizar_tiempo(tiempo_actual : int):
	label_tiempo_corredores.text = "Siguiente corredor en: " + str(tiempo_actual)

func _on_button_comenzar_juego_pressed() -> void:
	button_comenzar_juego.hide()
	timer_corredores.start()
	timer_segundos.start()
	#hasta aca solo en la pc del host
	
	lista_corredores_rojo.clear()
	lista_corredores_azul.clear()
	for id in Global.diccionario_equipos.keys():
		match Global.diccionario_equipos[id]["equipo"]:
			equipos_manager.EQUIPOS.ROJO:
				lista_corredores_rojo.push_back(id)
			equipos_manager.EQUIPOS.AZUL:
				lista_corredores_azul.push_back(id)
	#print("inicie el juego y la lista de equipos quedo con: ROJOS ", lista_corredores_rojo , " azules: ", lista_corredores_azul)
	seleccionar_corredores()

func _on_equipos_manager_equipos_actualizados(diccionario_equipos: Variant) -> void:
	#mostramos el boton unicamente despues de haber elegido equipo
	if !multiplayer.is_server(): #pq solo quiero q el host pueda iniciar el juego
		return
	await get_tree().create_timer(2).timeout
	print("ya se actualizo el equipo, mostrar boton de comenzar juego")
	button_comenzar_juego.show()
