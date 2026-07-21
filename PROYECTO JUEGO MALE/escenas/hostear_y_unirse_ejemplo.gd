extends Control
#esto va a servir como una especie de SteamManager, despues lo mejoramos visualmente pero en funcionamiento es esencialmente esto, crear lobbys, unirse, escribir id y listo el pollo


#para poder testear con una sola compu hago este enum que nos va a servir para cambiar entre steam y enet
@export_enum("STEAM", "ENET") var MULTIJUGADOR_TIPO : String = "STEAM"


const STEAM_APP_ID : int = 480 #480 vendria siendo el juego de prueba, el spacewars, cuando tengamos el ID de verdad lo ponemos (ojala sea prontito :) ) 
##Para setear cantidad maxima de jugadores que pueden entrar al lobby, 10 es un ejemplo solo para probar
@export var numero_maximo_jugadores : int = 10
@onready var button_host: Button = %ButtonHost
@onready var button_join: Button = %ButtonJoin
@onready var texto_id_sala: LineEdit = %TextoIDSala
@onready var label_id_colocado: Label = %LabelIDColocado

var lobby_id : int = 0
var peer 
var id_lobby_ingresado_manualmente : int

signal agregar_jugador(id_jugador : int)
signal quitar_jugador(id_jugador : int)

var es_host : bool = false
var uniendose_a_partida : bool = false

func _ready() -> void:
	if MULTIJUGADOR_TIPO == "ENET":
		peer = ENetMultiplayerPeer.new()
	else:
		peer = SteamMultiplayerPeer.new()
		print("Steam inicializado : ", Steam.steamInit(STEAM_APP_ID, true)) #poner los embed_callbacks en true hace que el plugin se encargue de verificar si hay callbacks de steam, lo mismo que haria si colocaramos Steam.run_callbacks() en el process (q nosotros no lo usamos de esa manera)
		Steam.initRelayNetworkAccess()
		Steam.lobby_created.connect(_on_lobby_creado)
		Steam.lobby_joined.connect(_on_lobby_joined)



func _on_button_host_pressed() -> void:
	if MULTIJUGADOR_TIPO == "ENET":
		peer.create_server(1027)
		#var err = peer.create_server(1027)
		#print("valor de err es:  ",err)
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected_agregar_jugador)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected_quitar_jugador)
		_on_peer_connected_agregar_jugador()
	else:
		#el primer parametro es el tipo de lobby, por ahora probamos solo con lobby publico
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, numero_maximo_jugadores)
		#con la linea de arriba se emite la signal lobby_created (que conecte en el ready)
	es_host = true
	#desactivo el boton nada mas pq al saltar con espacio se presionaba solo
	button_host.disabled = true


func _on_lobby_creado(resultado : int , lobby_id_parametro : int):
	if resultado == Steam.Result.RESULT_OK:
		print("Se creo el lobby correctamente")
		#seteo NUESTRO lobby id con el lobby que me da steam, q me lo pasa por parametro
		lobby_id = lobby_id_parametro
		print("Se seteo el lobby id con el valor: ", lobby_id_parametro)
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true 
		
		peer.create_host()
		multiplayer.multiplayer_peer = peer
		
		multiplayer.peer_connected.connect(_on_peer_connected_agregar_jugador)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected_quitar_jugador)
		#agrego al jugador manualmente pq es el host
		_on_peer_connected_agregar_jugador() #si el nombre de la funcion es larguisimo pero para no olvidarme el q hace
		
		DisplayServer.clipboard_set(str(lobby_id)) #pego en el portapapeles de la persona el LOBBY ID
		#para q no tenga que andar copiando y pegando
	else:
		print("Error al crear el lobby")


func _on_peer_connected_agregar_jugador(id : int = 1):
	print("Se unira un jugador con el ID ", id)
	agregar_jugador.emit(id) #esto lo dejo desacoplado para que se emita aca pero se ejecute en un spawner de jugadores
#sino la otra es hacer que este nodo tenga toooda la logica de spawnear tmb, no es mala esa


func _on_peer_disconnected_quitar_jugador(id : int):
	print("Se quitara al jugador con el ID ", id)
	quitar_jugador.emit(id)


func join_lobby(lobby_id : int = 0):
	uniendose_a_partida = true
	
	if MULTIJUGADOR_TIPO == "ENET":
		peer.create_client("127.0.0.1", 1027)
		multiplayer.multiplayer_peer = peer
	else:
		Steam.joinLobby(lobby_id)
		#esto tambien emite una signal llamada on_lobby_joined

func _on_lobby_joined(lobby_id_parametro : int , permisos : int , bloqueado : bool , respuesta : int):
	if not uniendose_a_partida:
		#no queremos ejecutar eso si ya se estaba uniendo a una partida
		return
	lobby_id = lobby_id_parametro
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_client(Steam.getLobbyOwner(lobby_id_parametro))
	multiplayer.multiplayer_peer = peer
	
	uniendose_a_partida = false
	print("el jugador se unio a la partida correctamente :D en el lobby : ", lobby_id_parametro)


func _on_button_join_pressed() -> void:
	join_lobby(id_lobby_ingresado_manualmente)
	button_host.disabled = false




func _on_texto_id_sala_text_submitted(new_text: String) -> void:
	button_host.disabled = true
	button_join.disabled = false
	texto_id_sala.set_focus_mode(Control.FOCUS_NONE)
	label_id_colocado.text = "Listo para unirse al ID: " + new_text
	id_lobby_ingresado_manualmente = int(new_text)
	#y ahora le quito el texto para reiniciarlo
	texto_id_sala.text = ""
