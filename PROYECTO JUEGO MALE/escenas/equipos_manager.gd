class_name EquiposManager
extends Control

#intento explicar como funciona
#el selector de equipos por ahora es simplemente 2 botones para 2 equipos
#cuando selecciono un equipo no puedo solamente escribir un diccionario o un json o agregar mi personaje a un array
#pq eso quedaria solamente de forma local (en una compu), entonces necesitamos centralizar todo en el servidor, mas bien la persona que haga de servidor

#en resumen, cuando seleccionamos un equipo, le aviso al servidor che me quiero unir a tal equipo (hasta ahi es solo una peticion)
#y el servidor se encarga de recibir esa peticion, procesarla (recibe algo tipo jugador ID: 123 quiere unirse al equipo : AZUL)
#como el servidor es la autoridad aca SI modificamos el diccionario

#ahora q el diccionario fue modificado y se agrego el jugador al equipo que el queria, le avisa a toooodos los jugadores del cambio
#y les manda a todos la lista actualizada
#por ultimo cada cliente reemplaza su diccionario por este q le mandó el servidor y listo el posho
# y de yapa se actualiza el hud para asegurarnos de que anda



signal equipos_actualizados(diccionario_equipos)
@export var vbox_label_equipos : VBoxContainer
@export var layer_equipos : CanvasLayer
enum EQUIPOS {ROJO, AZUL, ELIGIENDO}
var diccionario_equipos : Dictionary = {} #PARA LLENAR CON EL TIPO ID : EQUIPOS.ROJO o como sea mejor
const SERVER_ID := 1


func _ready() -> void:
	#layer_equipos.hide()
	pass

#PRIMER PASO, cuando se spawnee un jugador yo escribo en el diccionario y le aviso a los demas jugadores q entro alguien con la funcion sincronizar equipos
func _on_spawner_jugador_spawneado(id_multijugador: int, instancia_jugador: Player, nombre_steam_jugador: String) -> void:
	if !multiplayer.is_server():
		return
	diccionario_equipos[id_multijugador] = {"nombre" : nombre_steam_jugador, "equipo" : EQUIPOS.ELIGIENDO}
	sincronizar_equipos.rpc(diccionario_equipos)




func _on_button_equipo_azul_pressed() -> void:
	elegir_equipo(EQUIPOS.AZUL)


func _on_button_equipo_rojo_pressed() -> void:
	elegir_equipo(EQUIPOS.ROJO)


func elegir_equipo(equipo: EQUIPOS) -> void:
	solicitar_unirse_equipo.rpc_id(SERVER_ID, equipo) #le manda un paquete al peer 1 para q ejecute la funcion
	layer_equipos.hide()



@rpc("any_peer","reliable","call_local")
#any peer es pq aceptamos que cualquier jugador invoque a esta rpc
#reliable pq queremos asegurarnos de que llegue el dato, godot garantiza que llega (aunque a veces puede tardar un cachito mas pero llega)
#call local significa si esta llamada rpc tiene como destino la misma maquina q la llama, ejecutala tmb
func solicitar_unirse_equipo(equipo:EQUIPOS):
	if !multiplayer.is_server():#el return es pq queremos q esto se ejecute SOLAMENTE en la compu del server, sin el return se podria ejecutar en cualquier peer
		return
	var id := multiplayer.get_remote_sender_id() #para saber quien lo envio
	if id == 0: #si la funcion se ejecuta por call local significa q no vino por la red
		#en otras palabras el mismo host es quien llamo a la funcion y cuando eso pasa id vale 0
		id = multiplayer.get_unique_id() #sabiendo el el host se unio a un equipo, le damos el id 1
	
	
	if diccionario_equipos.has(id): #si el diccionario tiene al jugador q esta eligiendo equipo
		#que en teoria siempre lo va a tener, no deberia haber forma de que alguien eliga equipo
		#sin antes spawnear
		diccionario_equipos[id]["equipo"] = equipo
	
	sincronizar_equipos.rpc(diccionario_equipos)  #llamamos a la funcion con .rpc porque ahora si queremos q TODOS la ejecuten
	#en resumen le digo a todas las compus sincronicemos los equipos con este nuevo diccionario
	#print(diccionario_equipos)



@rpc("authority","reliable","call_local")
#authority es pq solamente la autoridad (el servidor) puede invocar esta RPC
func sincronizar_equipos(nuevo_diccionario:Dictionary): #aca le avisamos a todos q escriban en su diccionario, actualicen su hud etc etc
	diccionario_equipos = nuevo_diccionario
	
	#aca ya todos los jugadores tienen el miiismo diccionario
	#el resto es solo retocar el hud para ver nombre, id, equipo etc
	
	for hijo in vbox_label_equipos.get_children():
		hijo.queue_free() #limpio el hud viejo
	
	for id in diccionario_equipos.keys():
		var label_nuevo := Label.new() #por cada id hago un label nuevo
		var nombre_equipo = diccionario_equipos[id]["equipo"] #obtengo el nombre del equipo
		
		match nombre_equipo: #como era un enum necesito pasarlo a string
			EQUIPOS.AZUL:
				nombre_equipo = "AZUL"
			EQUIPOS.ROJO:
				nombre_equipo = "ROJO"
			EQUIPOS.ELIGIENDO:
				nombre_equipo = "ELIGIENDO"
				
		print("NOMBRE EQUIPO VALE: ", nombre_equipo)
		#label_nuevo.text = "Jugador %s -> %s" % [id, nombre_equipo]
		label_nuevo.text = "ID " + str(id) + " - " + diccionario_equipos[id]["nombre"] + " -->: " + nombre_equipo
		
		#label_nuevo.text = "Jugador: " + diccionario_equipos[id]["nombre"] + " -->: " + nombre_equipo
	
		vbox_label_equipos.add_child(label_nuevo)
	print(diccionario_equipos)
	#equipos_actualizados.emit(diccionario_equipos) #no hace nada todavia la deje x las dudas


func obtener_equipo(peer_id: int, equipo: EQUIPOS): #no la uso no le demos bola x ahora
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
