extends CharacterBody3D
class_name Player


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if not is_multiplayer_authority():
		%LineEdit.hide()
	var nombre_steam : String = Steam.getPersonaName()
	print(nombre_steam)
	setear_texto_label.rpc(nombre_steam)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return


func _on_line_edit_text_submitted(new_text: String) -> void:
	#%Label3D.text = texto #esta linea de codigo la ejecutariamos aca si fuera single player
	#al ser multijugador necesitamos hacer esto pero con una llamada rpc, entonces simplemente creo una funcion nueva
	
	
	#rpc("setear_texto_label", new_text) #esta es una manera de llamar la funcion rpc
	#pero a mi me gusta mas asi pq es mas comodo:
	setear_texto_label.rpc(new_text)

@rpc("authority", "call_local")
func setear_texto_label(texto : String):
	%Label3D.text = texto 
