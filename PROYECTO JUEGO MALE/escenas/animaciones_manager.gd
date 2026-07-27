class_name AnimacionesManager
extends Node


@export var animation_tree : AnimationTree


func ejecutar_animacion_idle():
	animation_tree.set("parameters/Animaciones/transition_request", "IDLE" )


func ejecutar_animacion_correr():
	animation_tree.set("parameters/Animaciones/transition_request", "CORRIENDO" )


func ejecutar_animacion_salto():
	animation_tree.set("parameters/Animaciones/transition_request", "SALTANDO" )
