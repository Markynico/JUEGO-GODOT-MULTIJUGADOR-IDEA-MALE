extends Node

var diccionario_equipos : Dictionary = {} #PARA LLENAR CON EL TIPO ID : EQUIPOS.ROJO o como sea mejor

#este es sooolamente local, no va a viajar por rpc ni se va a sincronizar
#cada Player se anota aca solito cuando entra al arbol (en TODAS las compus) y se borra al salir
var instancia_jugadores : Dictionary = {}

#los IDs de los que estan corriendo AHORA, esto si lo sincroniza el CorredoresManager por rpc
#si esta vacio significa que la partida todavia no arranco (y ahi todos pueden moverse)
var corredores_actuales : Array = []

func get_diccionario_equipos():
	return diccionario_equipos
