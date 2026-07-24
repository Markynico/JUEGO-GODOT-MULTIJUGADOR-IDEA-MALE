@tool
extends Node3D
class_name SistemaCheckpoints


signal checkpoint_alcanzado(jugador: Player, indice: int)
signal vuelta_completada(jugador: Player, vuelta: int)
signal carrera_terminada(jugador: Player)

enum Tipo { AUTO, CIRCUITO, SPRINT }

@export_tool_button("Regenerar", "Path3D") var boton_regenerar := generar

@export var cantidad_checkpoints: int = 3:
	set(value):
		cantidad_checkpoints = maxi(value, 0)
		_regenerar_en_editor()
@export var invertir_direccion: bool = false:
	set(value):
		invertir_direccion = value
		_regenerar_en_editor()
@export var tipo: Tipo = Tipo.AUTO:
	set(value):
		tipo = value
		notify_property_list_changed()
		_regenerar_en_editor()
@export var vueltas: int = 3:
	set(value):
		vueltas = maxi(value, 1)
@export var offset_largada: float = 30.0:
	set(value):
		offset_largada = maxf(value, 0.0)
		_regenerar_en_editor()
@export var offset_meta: float = 30.0:
	set(value):
		offset_meta = maxf(value, 0.0)
		_regenerar_en_editor()
@export_group("Dimensiones de los arcos")
@export var ancho: float = 0.0:
	set(value):
		ancho = maxf(value, 0.0)
		_regenerar_en_editor()
@export var alto: float = 8.0:
	set(value):
		alto = maxf(value, 1.0)
		_regenerar_en_editor()
@export var mostrar_gizmos: bool = true:
	set(value):
		mostrar_gizmos = value
		_regenerar_en_editor()
@export var visible_en_juego: bool = true:
	set(value):
		visible_en_juego = value
		_regenerar_en_editor()

var camino: Path3D
var es_circuito: bool = true
var arcos: Array[Area3D] = []
var progreso: Dictionary = {}
var carrera_activa: bool = true
var hud: CanvasLayer
var label_progreso: Label
var label_ganador: Label

func _ready() -> void:
	var pista := get_parent()
	if pista and pista.has_signal("pista_generada"):
		pista.pista_generada.connect(generar)
	if not Engine.is_editor_hint():
		_crear_hud()
	await get_tree().process_frame
	generar()

func _crear_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUDCarrera"
	label_progreso = Label.new()
	label_progreso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_progreso.position.y = 10.0
	label_progreso.add_theme_font_size_override("font_size", 24)
	label_progreso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(label_progreso)
	label_ganador = Label.new()
	label_ganador.set_anchors_preset(Control.PRESET_CENTER)
	label_ganador.add_theme_font_size_override("font_size", 48)
	label_ganador.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_ganador.hide()
	hud.add_child(label_ganador)
	add_child(hud)

func _actualizar_hud(datos: Dictionary) -> void:
	if label_progreso == null:
		return
	var total := arcos.size()
	var texto := ""
	if es_circuito:
		texto = "Vuelta %d/%d  -  Checkpoint %d/%d" % [mini(datos.vuelta, vueltas), vueltas, datos.siguiente, total]
	else:
		texto = "Checkpoint %d/%d" % [datos.siguiente, total - 1]
	label_progreso.text = texto

func _nombre_jugador(jugador: Player) -> String:
	var etiqueta := jugador.find_child("Label3D", true, false)
	if etiqueta and etiqueta is Label3D and not (etiqueta as Label3D).text.is_empty():
		return (etiqueta as Label3D).text
	return jugador.name

func generar() -> void:
	_limpiar()
	camino = _buscar_camino()
	if camino == null or camino.curve == null or camino.curve.point_count < 2:
		push_warning("SistemaCheckpoints: no se encontro un Path3D con curva en la pista.")
		return
	var curva := camino.curve
	es_circuito = curva.closed if tipo == Tipo.AUTO else tipo == Tipo.CIRCUITO
	var largo := curva.get_baked_length()
	var total := cantidad_checkpoints + (1 if es_circuito else 2)
	for i in total:
		var distancia: float
		if es_circuito:
			var paso := largo * float(i) / float(total)
			distancia = fposmod(offset_largada + (-paso if invertir_direccion else paso), largo)
		else:
			var inicio := minf(offset_largada, largo * 0.4)
			var fin := maxf(largo - offset_meta, inicio + 1.0)
			distancia = lerpf(inicio, fin, float(i) / float(total - 1))
			if invertir_direccion:
				distancia = largo - distancia
		var transformada := curva.sample_baked_with_rotation(distancia, true, true)
		var nombre := "Largada"
		if i > 0:
			nombre = "Meta" if (not es_circuito and i == total - 1) else "Checkpoint%d" % i
		_crear_arco(nombre, i, transformada)
	progreso.clear()
	carrera_activa = true
	if label_ganador:
		label_ganador.hide()
	if label_progreso:
		label_progreso.text = "Cruza la largada para empezar"

func _buscar_camino() -> Path3D:
	var raiz := get_parent()
	for candidato in [raiz, get_tree().current_scene if is_inside_tree() and not Engine.is_editor_hint() else null]:
		if candidato == null:
			continue
		var encontrado := _buscar_path3d(candidato)
		if encontrado:
			return encontrado
	if Engine.is_editor_hint() and is_inside_tree():
		var escena := get_tree().edited_scene_root
		if escena:
			return _buscar_path3d(escena)
	return null

func _buscar_path3d(nodo: Node) -> Path3D:
	if nodo is Path3D:
		return nodo
	for hijo in nodo.get_children():
		var encontrado := _buscar_path3d(hijo)
		if encontrado:
			return encontrado
	return null

func _ancho_arco() -> float:
	if ancho > 0.0:
		return ancho
	for nodo in [get_parent(), camino.get_parent() if camino else null]:
		if nodo and "ancho_de_pista" in nodo:
			return nodo.ancho_de_pista
	return 20.0

func _crear_arco(nombre: String, indice: int, transformada: Transform3D) -> void:
	var area := Area3D.new()
	area.name = nombre
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	var w := _ancho_arco()
	caja.size = Vector3(w, alto, 2.0)
	forma.shape = caja
	area.add_child(forma)
	add_child(area)
	var global_camino := camino.global_transform * transformada
	area.global_transform = global_camino
	area.global_position = global_camino.origin + global_camino.basis.x * (w * 0.5) + Vector3.UP * (alto * 0.5)
	area.body_entered.connect(_al_entrar.bind(indice))
	arcos.append(area)
	if mostrar_gizmos if Engine.is_editor_hint() else visible_en_juego:
		var visual := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = caja.size
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.2, 1.0, 0.3, 0.35) if indice == 0 else Color(1.0, 0.8, 0.1, 0.25)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		malla.material = material
		visual.mesh = malla
		area.add_child(visual)

func _limpiar() -> void:
	for arco in arcos:
		if is_instance_valid(arco):
			arco.queue_free()
	arcos.clear()
	for hijo in get_children():
		if hijo is Area3D:
			hijo.queue_free()

func _regenerar_en_editor() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		generar()

func _al_entrar(cuerpo: Node3D, indice: int) -> void:
	if Engine.is_editor_hint() or not cuerpo is Player:
		return
	var jugador := cuerpo as Player
	if not progreso.has(jugador):
		progreso[jugador] = {"siguiente": 0, "vuelta": 1}
	var datos: Dictionary = progreso[jugador]
	if indice != datos.siguiente:
		return
	checkpoint_alcanzado.emit(jugador, indice)
	var total := arcos.size()
	if es_circuito:
		datos.siguiente = (indice + 1) % total
		if indice == 0 and datos.vuelta > 0 and datos.get("paso_por_todos", false):
			vuelta_completada.emit(jugador, datos.vuelta)
			datos.vuelta += 1
			datos.paso_por_todos = false
			if datos.vuelta > vueltas:
				_finalizar(jugador)
				return
		if indice == total - 1:
			datos.paso_por_todos = true
	else:
		datos.siguiente = indice + 1
		if indice == total - 1:
			_finalizar(jugador)
			return
	if jugador.is_multiplayer_authority():
		_actualizar_hud(datos)

func _finalizar(jugador: Player) -> void:
	carrera_terminada.emit(jugador)
	progreso.erase(jugador)
	if carrera_activa and multiplayer.is_server():
		carrera_activa = false
		_anunciar_ganador.rpc(_nombre_jugador(jugador))

@rpc("authority", "call_local", "reliable")
func _anunciar_ganador(nombre: String) -> void:
	carrera_activa = false
	if label_ganador:
		label_ganador.text = "GANADOR: %s" % nombre
		label_ganador.show()
