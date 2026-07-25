class_name CorredoresManager
extends Node

#Este nodo decide QUIEN corre y QUIEN esta espectando.
#Como es una decision de juego, la toma SOLAMENTE el server y despues se la avisa a todos por rpc.
#El error de antes era que se emitian las signals cambiar_a_modo_espectador/corredor sobre las
#instancias que tiene el server, y esas signals son locales: nunca cruzaban la red, asi que en la
#compu del cliente nunca pasaba nada (y encima los managers del personaje solo conectan esas
#signals si son la authority, o sea que en la compu del server ni siquiera estaban conectadas).

@onready var button_comenzar_juego: Button = %ButtonComenzarJuego
@onready var label_tiempo_corredores: Label = %LabelTiempoCorredores
@onready var timer_corredores: Timer = %TimerCorredores
@onready var timer_segundos: Timer = %TimerSegundos
@onready var equipos_manager: EquiposManager = %EquiposManager


const SERVER_ID := 1

var tiempo_x_ronda : int = 90
var tiempo_actual : int

var juego_iniciado : bool = false

var lista_corredores_rojo : Array = []
var lista_corredores_azul : Array = []


func _ready() -> void:
	tiempo_actual = tiempo_x_ronda
	button_comenzar_juego.hide()
	label_tiempo_corredores.text = "Esperando que empiece la partida..."
	#los timers los arranca el server cuando se aprieta el boton, no antes
	timer_corredores.stop()
	timer_segundos.stop()


#==============================================================================
# ARRANQUE DE LA PARTIDA (solo server)
#==============================================================================

func _on_equipos_manager_equipos_actualizados(diccionario_equipos: Variant) -> void:
	#mostramos el boton unicamente cuando ya hay al menos 1 jugador en cada equipo
	if !multiplayer.is_server(): #pq solo quiero q el host pueda iniciar el juego
		return
	if juego_iniciado:
		return
	#antes habia un await de 2 segundos aca que se apilaba una vez por cada cambio de equipo
	#y mostraba el boton aunque faltara gente, ahora lo chequeamos de verdad
	if _hay_equipos_completos(diccionario_equipos):
		button_comenzar_juego.show()
	else:
		button_comenzar_juego.hide()


func _hay_equipos_completos(diccionario_equipos : Dictionary) -> bool:
	var hay_rojo : bool = false
	var hay_azul : bool = false
	for id in diccionario_equipos.keys():
		match diccionario_equipos[id]["equipo"]:
			EquiposManager.EQUIPOS.ROJO:
				hay_rojo = true
			EquiposManager.EQUIPOS.AZUL:
				hay_azul = true
	return hay_rojo and hay_azul


func _on_button_comenzar_juego_pressed() -> void:
	if !multiplayer.is_server():
		return

	#armo las listas de cada equipo desde el diccionario que sincronizo el EquiposManager
	#esto lo hago ANTES de arrancar los timers, sino podiamos arrancar con listas vacias
	#(que era justamente el motivo de que pop_front() devolviera null y explotara)
	lista_corredores_rojo.clear()
	lista_corredores_azul.clear()
	for id in Global.diccionario_equipos.keys():
		match Global.diccionario_equipos[id]["equipo"]:
			EquiposManager.EQUIPOS.ROJO:
				lista_corredores_rojo.push_back(id)
			EquiposManager.EQUIPOS.AZUL:
				lista_corredores_azul.push_back(id)

	if lista_corredores_rojo.is_empty() or lista_corredores_azul.is_empty():
		print("No se puede empezar: hace falta al menos 1 jugador por equipo. ROJOS: ",
				lista_corredores_rojo, " AZULES: ", lista_corredores_azul)
		return #dejo el boton visible para que lo pueda volver a intentar

	juego_iniciado = true
	button_comenzar_juego.hide()
	tiempo_actual = tiempo_x_ronda
	timer_corredores.start()
	timer_segundos.start()
	sincronizar_tiempo.rpc(tiempo_actual)
	seleccionar_corredores()


#==============================================================================
# ROTACION DE CORREDORES (solo server)
#==============================================================================

func _on_timer_corredores_timeout() -> void:
	if !multiplayer.is_server():
		return
	#esto va a sonar cuando terminen los 90 segundos
	tiempo_actual = tiempo_x_ronda #reinicio el segundero
	#el TimerCorredores no es one_shot, se reinicia solo, no hace falta el .start()
	seleccionar_corredores()


func seleccionar_corredores() -> void:
	if !multiplayer.is_server():
		return
	if lista_corredores_rojo.is_empty() or lista_corredores_azul.is_empty():
		print("No hay corredores suficientes para rotar, corto la ronda")
		return

	#saco el primero de la lista y lo manda al fondo, asi van rotando en orden
	var corredor_rojo = lista_corredores_rojo.pop_front()
	lista_corredores_rojo.push_back(corredor_rojo)

	var corredor_azul = lista_corredores_azul.pop_front()
	lista_corredores_azul.push_back(corredor_azul)

	print("Corredor rojo: ", corredor_rojo, " | Corredor azul: ", corredor_azul)

	#y aca esta la parte importante: le aviso a TODAS las compus quienes corren
	aplicar_corredores.rpc([corredor_rojo, corredor_azul])


@rpc("authority", "reliable", "call_local")
#authority + call_local: lo decide el server y se ejecuta en todos, incluido el propio server
func aplicar_corredores(corredores : Array) -> void:
	Global.corredores_actuales = corredores #lo guardo para los que spawneen despues

	#recorro TODOS los jugadores que existen en esta compu y le doy a cada uno su modo
	#(instancia_jugadores se llena solo, cada Player se anota en su _ready)
	for id in Global.instancia_jugadores.keys():
		var jugador : Player = Global.instancia_jugadores[id]
		if not is_instance_valid(jugador):
			continue
		jugador.aplicar_modo(id in corredores)


#==============================================================================
# SEGUNDERO
#==============================================================================

func _on_timer_segundos_timeout() -> void:
	if !multiplayer.is_server():
		return
	tiempo_actual -= 1
	if tiempo_actual < 0:
		tiempo_actual = 0
	sincronizar_tiempo.rpc(tiempo_actual) #para q todos los jugadores tengan el label actualizado con el mismo tiempo


@rpc("authority", "reliable", "call_local")
func sincronizar_tiempo(tiempo : int) -> void: #antes el parametro se llamaba igual que la variable de arriba y la tapaba
	label_tiempo_corredores.text = "Siguiente corredor en: " + str(tiempo)
