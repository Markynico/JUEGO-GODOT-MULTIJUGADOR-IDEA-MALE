extends Control

@export var progress_bar_nitro : ProgressBar
@export var body : Player

func _ready() -> void:
	if not body.is_multiplayer_authority():
		progress_bar_nitro.hide()

func set_progress_bar_nitro_value(valor_nitro : float): #se emite una signal en NITRO MANAGER y ejecuta esta funcion
	progress_bar_nitro.value = valor_nitro
