class_name EquiposManager
extends Control

signal equipos_actualizados(diccionario_equipos)
@export var vbox_label_equipos : VBoxContainer
@export var layer_equipos : CanvasLayer
enum EQUIPOS {ROJO, AZUL}
var diccionario_equipos : Dictionary = {} #PARA LLENAR CON EL TIPO ID : EQUIPOS.ROJO o como sea mejor
const SERVER_ID := 1


func _ready() -> void:
	#layer_equipos.hide()
	pass



func _on_button_equipo_azul_pressed() -> void:
	elegir_equipo(EQUIPOS.AZUL)


func _on_button_equipo_rojo_pressed() -> void:
	elegir_equipo(EQUIPOS.ROJO)


func elegir_equipo(equipo: EQUIPOS) -> void:
	solicitar_unirse_equipo.rpc_id(SERVER_ID, equipo)
	layer_equipos.hide()



@rpc("any_peer","reliable","call_local")
func solicitar_unirse_equipo(equipo:EQUIPOS):
	if !multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	diccionario_equipos[id] = equipo
	sincronizar_equipos.rpc(diccionario_equipos)
	print(diccionario_equipos)


@rpc("authority","reliable","call_local")
func sincronizar_equipos(nuevo_diccionario:Dictionary):
	diccionario_equipos = nuevo_diccionario
	equipos_actualizados.emit(diccionario_equipos)
	#aca se supone q se agrego una eprsona
	
	for hijo in vbox_label_equipos.get_children():
		hijo.queue_free() #limpio
	
	for id in diccionario_equipos.keys():
		var label_nuevo := Label.new() 
		
		var nombre_equipo := "ROJO" #MUY UNGA UNGA PERO BUENO
		if diccionario_equipos[id] == EQUIPOS.AZUL:
			nombre_equipo = "AZUL"
		label_nuevo.text = "Jugador %s -> %s" % [id, nombre_equipo]
	
		vbox_label_equipos.add_child(label_nuevo)
	print(diccionario_equipos)


func obtener_equipo(peer_id: int, equipo: EQUIPOS):
	return diccionario_equipos.get(peer_id) == equipo 



func _on_hostear_y_unirse_ejemplo_agregar_jugador(id_jugador: int) -> void:
	print("Se ejecutó agregar_jugador", id_jugador, multiplayer.get_unique_id())
	print("mi id:", multiplayer.get_unique_id())
	#if id_jugador != multiplayer.get_unique_id(): #para mostrarle el hud solo al jugador q recien se une
		#return
	print("ahora q spawneo un personaje muestro el selector de equipos")
	layer_equipos.show()


func _on_button_cerrar_pressed() -> void:
	layer_equipos.hide() #a manopla pq es prototipo
