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

@export var tiempo_x_ronda : int = 15
var tiempo_actual : int

var juego_iniciado : bool = false

var lista_corredores_rojo : Array = []
var lista_corredores_azul : Array = []


func _ready() -> void:
	tiempo_actual = tiempo_x_ronda
	#le paso el tiempo al timer desde acá para no tener el numero repetido en la escena
	timer_corredores.wait_time = tiempo_x_ronda
	timer_segundos.wait_time = 1.0
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
	#y mostraba el boton aunque no hubiera nadie, ahora lo chequeamos de verdad
	#no pedimos los dos equipos llenos: con un equipo vacio la partida igual funciona,
	#simplemente corre uno solo y el otro carril queda libre
	if _hay_alguien_en_un_equipo(diccionario_equipos):
		button_comenzar_juego.show()
	else:
		button_comenzar_juego.hide()


func _hay_alguien_en_un_equipo(diccionario_equipos : Dictionary) -> bool:
	for id in diccionario_equipos.keys():
		match diccionario_equipos[id]["equipo"]:
			EquiposManager.EQUIPOS.ROJO, EquiposManager.EQUIPOS.AZUL:
				return true #con uno solo que haya elegido equipo ya alcanza
	return false


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

	#alcanza con que haya UN equipo con gente, si el otro esta vacio corre uno solo
	if lista_corredores_rojo.is_empty() and lista_corredores_azul.is_empty():
		print("No se puede empezar: no hay nadie que haya elegido equipo todavia")
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
	#esto va a sonar cada vez que se termine la ronda (tiempo_x_ronda segundos)
	tiempo_actual = tiempo_x_ronda #reinicio el segundero
	#el TimerCorredores no es one_shot, se reinicia solo, no hace falta el .start()
	seleccionar_corredores()


func seleccionar_corredores() -> void:
	if !multiplayer.is_server():
		return

	#saco de las listas a los que ya no estan, sino le tocaria el turno a un fantasma
	#y la ronda se pasaria entera sin que corra nadie de ese equipo
	_limpiar_desconectados(lista_corredores_rojo)
	_limpiar_desconectados(lista_corredores_azul)

	#cada equipo aporta como maximo UN corredor, y cada lista rota por separado
	#si un equipo esta vacio simplemente no aporta a nadie (antes esto devolvia null y explotaba)
	var corredores : Array = []
	var corredor_rojo = _rotar_lista(lista_corredores_rojo)
	if corredor_rojo != null:
		corredores.append(corredor_rojo)
	var corredor_azul = _rotar_lista(lista_corredores_azul)
	if corredor_azul != null:
		corredores.append(corredor_azul)

	if corredores.is_empty():
		print("Se quedo sin corredores (se fueron todos?), paro la rotacion")
		timer_corredores.stop()
		timer_segundos.stop()
		juego_iniciado = false
		aplicar_corredores.rpc([])
		return

	print("Corredor rojo: ", corredor_rojo, " | Corredor azul: ", corredor_azul)

	#y aca esta la parte importante: le aviso a TODAS las compus quienes corren
	aplicar_corredores.rpc(corredores)


##Saca el primero de la lista y lo manda al fondo, asi van rotando en orden y le toca a todos.
##Devuelve null si el equipo esta vacio.
##Si el equipo tiene un solo jugador siempre devuelve el mismo, o sea que se queda corriendo
##(no hay con quien rotar, y eso esta bien)
func _rotar_lista(lista : Array):
	if lista.is_empty():
		return null
	var corredor = lista.pop_front()
	lista.push_back(corredor)
	return corredor


##Voy de atras para adelante porque estoy borrando mientras recorro
func _limpiar_desconectados(lista : Array) -> void:
	for i in range(lista.size() - 1, -1, -1):
		if not Global.instancia_jugadores.has(lista[i]):
			print("Saco de la rotacion al jugador ", lista[i], " porque ya no esta")
			lista.remove_at(i)


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
