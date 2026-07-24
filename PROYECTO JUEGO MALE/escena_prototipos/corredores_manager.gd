extends Node


@onready var button_comenzar_juego: Button = %ButtonComenzarJuego


func _ready() -> void:
	button_comenzar_juego.hide()





func _on_timer_corredores_timeout() -> void:
	pass # Replace with function body.
