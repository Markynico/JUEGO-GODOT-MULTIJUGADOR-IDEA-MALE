extends CharacterBody3D
class_name Player

signal cambiar_a_modo_espectador #CAMBIAR A MODO ESPECTADOR INICIADO
signal cambiar_a_modo_corredor

var es_corredor : bool = true


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	#me anoto en el diccionario local para que el CorredoresManager me pueda encontrar
	#esto pasa en TODAS las compus, no solo en la del server
	Global.instancia_jugadores[name.to_int()] = self

	if not is_multiplayer_authority():
		%LineEdit.hide()
	else:
		#solo el dueño del personaje puede llamar a la rpc de authority, sino tira error
		var nombre_steam : String = get_nombre_steam() #si estamos en modo ENET va a dar error, no se preocupen
		print("NOMBRE STEAM VALE: ",nombre_steam)
		#si estamos en enet nombre steam queda como un string vacio ""
		setear_texto_label.rpc(nombre_steam)

	#si me spawneo con la partida ya empezada arranco con el modo que corresponda
	#(esto ademas nos cubre si el paquete del spawn llega despues que la rpc de corredores)
	if not Global.corredores_actuales.is_empty():
		aplicar_modo(name.to_int() in Global.corredores_actuales)


func _exit_tree() -> void:
	Global.instancia_jugadores.erase(name.to_int())


##La llama el CorredoresManager en TODAS las compus, asi todos ven lo mismo
func aplicar_modo(nuevo_es_corredor : bool) -> void:
	es_corredor = nuevo_es_corredor
	#la parte visual la apagamos en todas las compus, sino el resto seguiria viendo
	#al espectador parado en el medio de la pista
	$MeshInstance3D.visible = es_corredor
	%Label3D.visible = es_corredor
	#y aca aviso a los managers (movimiento y camaras) que hagan lo suyo
	if es_corredor:
		cambiar_a_modo_corredor.emit()
	else:
		cambiar_a_modo_espectador.emit()

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


func get_nombre_steam():
	var nombre_steam : String = Steam.getPersonaName()
	return nombre_steam
