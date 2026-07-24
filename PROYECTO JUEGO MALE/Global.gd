extends Node

var diccionario_equipos : Dictionary = {} #PARA LLENAR CON EL TIPO ID : EQUIPOS.ROJO o como sea mejor

#este es sooolamente local, no va a viajar por rpc ni se va a sincronizar
var instancia_jugadores : Dictionary = {}

func get_diccionario_equipos():
	return diccionario_equipos
