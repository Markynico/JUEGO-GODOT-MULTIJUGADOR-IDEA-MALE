@tool
extends Node3D
class_name SistemaCheckpoints

## Nodo drop-in: se agrega como hijo (o hermano) de una pista con Path3D y
## genera automaticamente la largada, la meta y los checkpoints sobre la curva.

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
## AUTO detecta segun la curva (cerrada = circuito, abierta = sprint).
@export var tipo: Tipo = Tipo.AUTO:
	set(value):
		tipo = value
		notify_property_list_changed()
		_regenerar_en_editor()
## Solo se usa si la pista es un circuito.
@export var vueltas: int = 3:
	set(value):
		vueltas = maxi(value, 1)
## Metros de pista libres antes de la linea de largada.
@export var offset_largada: float = 30.0:
	set(value):
		offset_largada = maxf(value, 0.0)
		_regenerar_en_editor()
## Metros de pista libres despues de la meta (solo sprint).
@export var offset_meta: float = 30.0:
	set(value):
		offset_meta = maxf(value, 0.0)
		_regenerar_en_editor()
@export_group("Dimensiones de los arcos")
## 0 = detectar ancho_de_pista de la pista automaticamente.
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
## Muestra los arcos tambien durante la partida.
@export var visible_en_juego: bool = true:
	set(value):
		visible_en_juego = value
		_regenerar_en_editor()

var camino: Path3D
var es_circuito: bool = true
var arcos: Array[Area3D] = []
# Por jugador: {"siguiente": indice del proximo arco, "vuelta": vuelta actual}
var progreso: Dictionary = {}

func _ready() -> void:
	var pista := get_parent()
	if pista and pista.has_signal("pista_generada"):
		pista.pista_generada.connect(generar)
	# La pista procedural genera su Path3D en su propio _ready; esperar un frame.
	await get_tree().process_frame
	generar()

func generar() -> void:
	_limpiar()
	camino = _buscar_camino()
	if camino == null or camino.curve == null or camino.curve.point_count < 2:
		push_warning("SistemaCheckpoints: no se encontro un Path3D con curva en la pista.")
		return
	var curva := camino.curve
	es_circuito = curva.closed if tipo == Tipo.AUTO else tipo == Tipo.CIRCUITO
	var largo := curva.get_baked_length()
	# Cantidad de arcos: largada + checkpoints (+ meta separada solo en sprint).
	var total := cantidad_checkpoints + (1 if es_circuito else 2)
	for i in total:
		var distancia: float
		if es_circuito:
			# La largada arranca con offset y los arcos reparten la vuelta completa.
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

func _buscar_camino() -> Path3D:
	# Primero en el padre (nodo pista), despues en toda la escena.
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
	# Detectar el ancho de la pista si el nodo lo expone.
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
	# La curva es el borde izquierdo de la pista: centrar el arco sobre el ancho.
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
				carrera_terminada.emit(jugador)
				progreso.erase(jugador)
				return
		if indice == total - 1:
			datos.paso_por_todos = true
	else:
		datos.siguiente = indice + 1
		if indice == total - 1:
			carrera_terminada.emit(jugador)
			progreso.erase(jugador)
