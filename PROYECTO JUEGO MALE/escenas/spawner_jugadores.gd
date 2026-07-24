@icon("res://2d/iconos_personalizados/icono_spawner.png")
class_name SpawnerJugadores
extends Node3D


@onready var marker_position: Marker3D = %MarkerPosition
@export var escena_jugador : PackedScene
signal jugador_spawneado(id_multijugador : int , instancia_jugador : Player, nombre_steam_jugador :String)


func spawnear_jugador(id_desde_steam_manager : int = 0): #esta funcion se ejecuta cuando se emite la signal AGREGAR JUGADOR del nodo control q maneja las cosas de steam
	var instancia_jugador : Player = escena_jugador.instantiate()
	setear_id_jugador(id_desde_steam_manager, instancia_jugador)
	add_child(instancia_jugador)
	instancia_jugador.global_position = marker_position.global_position
	var nombre_steam : String = instancia_jugador.get_nombre_steam()
	#print("SE INSTANCIO Y NOMBRE STEAM VALE: ", nombre_steam)
	jugador_spawneado.emit(id_desde_steam_manager, instancia_jugador, nombre_steam)


func setear_id_jugador(id_desde_steam_manager : int, instancia_jugador):
	if id_desde_steam_manager!= 0:
		instancia_jugador.name = str(id_desde_steam_manager)
	else:
		print("No le seteo el nombre al nodo pq no spawneo desde el steam manager")
		#por si queremos reutilizar este spawner para un modo single player (?
