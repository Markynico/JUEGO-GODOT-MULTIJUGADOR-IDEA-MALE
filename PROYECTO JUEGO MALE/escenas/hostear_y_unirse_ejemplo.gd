extends Control
#esto va a servir como una especie de SteamManager, despues lo mejoramos visualmente pero en funcionamiento es esencialmente esto, crear lobbys, unirse, escribir id y listo el pollo


#para poder testear con una sola compu hago este enum que nos va a servir para cambiar entre steam y enet
@export_enum("STEAM", "ENET") var MULTIJUGADOR_TIPO : String = "STEAM"


const STEAM_APP_ID : int = 480 #480 vendria siendo el juego de prueba, el spacewars, cuando tengamos el ID de verdad lo ponemos (ojala sea prontito :) )
##Para setear cantidad maxima de jugadores que pueden entrar al lobby, 10 es un ejemplo solo para probar
@export var numero_maximo_jugadores : int = 10
##PUBLIC lo puede encontrar cualquiera con el mismo app id, FRIENDS_ONLY solo nuestros amigos.
##Para entrar desde la lista de amigos funcionan los dos, pero FRIENDS_ONLY es mas prolijo
##cuando tengamos el app id de verdad
@export_enum("PUBLIC", "FRIENDS_ONLY", "INVISIBLE") var TIPO_DE_LOBBY : String = "PUBLIC"
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
		#TODO ESTO ES PARA PODER ENTRAR DESDE LA LISTA DE AMIGOS DE STEAM:
		#cuando el amigo aprieta "Unirse a la partida" y NOSOTROS ya tenemos el juego abierto
		Steam.join_requested.connect(_on_join_requested)
		#lo mismo pero cuando steam nos pasa el connect string en vez del lobby directo
		Steam.join_game_requested.connect(_on_join_game_requested)
		#cuando nos llega una invitacion (el overlay ya muestra el cartelito, esto es solo para loguear)
		Steam.lobby_invite.connect(_on_lobby_invite)
		#y si steam ABRIO el juego para unirnos a un amigo, el lobby viene en la linea de comandos
		_chequear_lobby_de_arranque.call_deferred()



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
		#el primer parametro es el tipo de lobby, ahora se elige con el export TIPO_DE_LOBBY
		Steam.createLobby(_obtener_tipo_de_lobby(), numero_maximo_jugadores)
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

		#me aseguro de que el lobby acepte gente y le pongo un nombre asi se ve algo lindo
		Steam.setLobbyJoinable(lobby_id, true)
		Steam.setLobbyData(lobby_id, "nombre_partida", Steam.getPersonaName())
		_publicar_partida_en_steam() #ACA se habilita el "Unirse a la partida" de la lista de amigos

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
	#este guard es sobre todo por las invitaciones de steam: si ya estamos hosteando o ya
	#estamos dentro de una partida, no queremos pisar el peer y quedar en un estado raro
	#(antes de conectarnos multiplayer_peer es el OfflineMultiplayerPeer que pone godot solo,
	#por eso pregunto por el tipo y no con has_multiplayer_peer)
	if es_host or multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		print("Ya estamos en una partida, ignoro el pedido de unirse al lobby ", lobby_id)
		return
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
	#yo tambien publico la partida, asi MIS amigos me pueden seguir a este mismo lobby
	_publicar_partida_en_steam()
	print("el jugador se unio a la partida correctamente :D en el lobby : ", lobby_id_parametro)


func _on_button_join_pressed() -> void:
	join_lobby(id_lobby_ingresado_manualmente)
	button_host.disabled = false




#==============================================================================
# ENTRAR DESDE LA LISTA DE AMIGOS DE STEAM
#==============================================================================

##El rich presence "connect" es LO QUE HACE que a nuestros amigos les aparezca el boton
##"Unirse a la partida" al lado de nuestro nombre en la lista de amigos de steam.
##Steam guarda ese texto y cuando el amigo aprieta el boton nos lo devuelve (o se lo pasa
##al juego por linea de comandos si todavia no lo tiene abierto).
func _publicar_partida_en_steam() -> void:
	if MULTIJUGADOR_TIPO == "ENET":
		return
	if lobby_id == 0:
		return
	Steam.setRichPresence("connect", "+connect_lobby " + str(lobby_id))
	Steam.setRichPresence("status", "En una partida")
	print("Partida publicada en steam, los amigos ya pueden entrar al lobby ", lobby_id)


##Se ejecuta cuando el amigo aprieta "Unirse a la partida" y nosotros YA tenemos el juego abierto
func _on_join_requested(lobby_id_parametro : int, steam_id_amigo : int) -> void:
	print("Nos quieren llevar al lobby ", lobby_id_parametro, " (invita el steam id ", steam_id_amigo, ")")
	join_lobby(lobby_id_parametro)


##Igual que la de arriba pero steam nos manda el connect string en vez del lobby pelado
func _on_join_game_requested(steam_id_amigo : int, connect_string : String) -> void:
	print("Nos llego un connect string de ", steam_id_amigo, ": ", connect_string)
	var id_lobby : int = _sacar_lobby_id_del_texto(connect_string)
	if id_lobby == 0:
		print("No pude sacar el lobby id del connect string")
		return
	join_lobby(id_lobby)


##El overlay de steam ya muestra el cartelito de la invitacion, esto es solo para ver que llego
func _on_lobby_invite(steam_id_invitador : int, lobby_id_parametro : int, id_del_juego : int) -> void:
	print("Invitacion de ", steam_id_invitador, " al lobby ", lobby_id_parametro, " del juego ", id_del_juego)


##Si el juego estaba CERRADO y el amigo aprieta "Unirse a la partida", steam abre el juego
##y nos pasa el connect string por linea de comandos, asi que hay que revisarla al arrancar
func _chequear_lobby_de_arranque() -> void:
	var id_lobby : int = _sacar_lobby_id_del_texto(" ".join(OS.get_cmdline_args()))
	if id_lobby == 0:
		#por las dudas pruebo tambien con la que nos da steam, que funciona cuando el juego
		#se abre desde un link steam:// en vez de con argumentos normales
		id_lobby = _sacar_lobby_id_del_texto(Steam.getLaunchCommandLine())
	if id_lobby == 0:
		return #arranque normal, no venimos de la lista de amigos
	print("Steam nos abrio el juego para entrar al lobby ", id_lobby)
	button_host.disabled = true
	label_id_colocado.text = "Entrando a la partida de un amigo..."
	join_lobby(id_lobby)


##Busca el "+connect_lobby <id>" dentro de un texto y devuelve el id, o 0 si no lo encuentra
func _sacar_lobby_id_del_texto(texto : String) -> int:
	if texto.is_empty():
		return 0
	var partes : PackedStringArray = texto.split(" ", false)
	for i in partes.size():
		if partes[i] == "+connect_lobby" and i + 1 < partes.size():
			return int(partes[i + 1])
	return 0


func _obtener_tipo_de_lobby() -> int:
	match TIPO_DE_LOBBY:
		"FRIENDS_ONLY":
			return Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
		"INVISIBLE":
			return Steam.LobbyType.LOBBY_TYPE_INVISIBLE
		_:
			return Steam.LobbyType.LOBBY_TYPE_PUBLIC


##Abre el overlay de steam con la lista de amigos para invitar. Se puede colgar de un boton.
func abrir_invitacion_de_steam() -> void:
	if MULTIJUGADOR_TIPO == "ENET" or lobby_id == 0:
		return
	Steam.activateGameOverlayInviteDialog(lobby_id)


func _on_texto_id_sala_text_submitted(new_text: String) -> void:
	button_host.disabled = true
	button_join.disabled = false
	texto_id_sala.set_focus_mode(Control.FOCUS_NONE)
	label_id_colocado.text = "Listo para unirse al ID: " + new_text
	id_lobby_ingresado_manualmente = int(new_text)
	#y ahora le quito el texto para reiniciarlo
	texto_id_sala.text = ""
