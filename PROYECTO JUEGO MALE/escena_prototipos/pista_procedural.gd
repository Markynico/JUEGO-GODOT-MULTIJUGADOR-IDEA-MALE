@tool
extends Node3D

enum Modo { CIRCUITO, SPRINT }

@export_tool_button("Nueva Seed", "RandomNumberGenerator") var boton_nueva_seed := nueva_seed
@export var modo: Modo = Modo.CIRCUITO:
	set(value):
		modo = value
		if is_inside_tree():
			generar()
@export var seed_pista: int = 0:
	set(value):
		seed_pista = value
		if is_inside_tree():
			generar()
@export var cantidad_puntos: int = 12:
	set(value):
		cantidad_puntos = clampi(value, 4, 64)
		if is_inside_tree():
			generar()
@export var largo_pista: float = 1500.0:
	set(value):
		largo_pista = value
		if is_inside_tree():
			generar()
@export var variacion_altura: float = 15.0:
	set(value):
		variacion_altura = value
		if is_inside_tree():
			generar()
@export_range(0.0, 100.0, 1.0, "suffix:%") var desviacion: float = 0.0:
	set(value):
		desviacion = value
		if is_inside_tree():
			generar()
@export_range(0.0, 1.0) var probabilidad_recta: float = 0.25:
	set(value):
		probabilidad_recta = value
		if is_inside_tree():
			generar()
@export_range(0.5, 8.0) var colinas: float = 2.0:
	set(value):
		colinas = value
		if is_inside_tree():
			generar()
@export var suavidad: float = 0.4:
	set(value):
		suavidad = clampf(value, 0.1, 1.0)
		if is_inside_tree():
			generar()
@export_range(0.0, 90.0) var curvatura: float = 30.0:
	set(value):
		curvatura = value
		if is_inside_tree():
			generar()
@export var resolver_cruces: bool = true:
	set(value):
		resolver_cruces = value
		if is_inside_tree():
			generar()
@export var altura_puente: float = 12.0:
	set(value):
		altura_puente = value
		if is_inside_tree():
			generar()
@export var ancho_de_pista: float = 20.0:
	set(value):
		ancho_de_pista = value
		if is_inside_tree():
			generar()
@export var alto_borde: float = 2.0:
	set(value):
		alto_borde = value
		if is_inside_tree():
			generar()
@export var grosor_borde: float = 1.0:
	set(value):
		grosor_borde = value
		if is_inside_tree():
			generar()
@export var textura_pista: Texture2D:
	set(value):
		textura_pista = value
		if is_inside_tree():
			generar()

var rectas: Array[int] = []
var ajustes: Dictionary = {}
var camino: Path3D
var pista: CSGPolygon3D
var borde_izq: CSGPolygon3D
var borde_der: CSGPolygon3D

func nueva_seed() -> void:
	seed_pista = randi()

func _ready() -> void:
	generar()

func generar() -> void:
	_asegurar_nodos()
	camino.curve = _generar_curva()
	for csg in [pista, borde_izq, borde_der]:
		csg.path_joined = modo == Modo.CIRCUITO
	_actualizar_poligonos()

func _asegurar_nodos() -> void:
	if camino:
		return
	camino = get_node_or_null("Path3D")
	if camino == null:
		camino = Path3D.new()
		camino.name = "Path3D"
		add_child(camino)
		pista = _crear_csg("Pista")
		borde_izq = _crear_csg("BordeIzq")
		borde_der = _crear_csg("BordeDer")
	else:
		pista = camino.get_node("Pista")
		borde_izq = camino.get_node("BordeIzq")
		borde_der = camino.get_node("BordeDer")

func _crear_csg(nombre: String) -> CSGPolygon3D:
	var csg := CSGPolygon3D.new()
	csg.name = nombre
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = NodePath("..")
	csg.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	csg.path_interval = 1.0
	csg.path_simplify_angle = 0.0
	csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	csg.path_rotation_accurate = true
	csg.path_local = true
	csg.path_continuous_u = true
	csg.path_joined = true
	csg.use_collision = true
	camino.add_child(csg)
	return csg

func _generar_curva() -> Curve3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_pista
	var curva := Curve3D.new()
	curva.closed = modo == Modo.CIRCUITO
	ajustes = {
		"variacion_altura": _desviar(rng, variacion_altura, 0.0, 40.0),
		"colinas": _desviar(rng, colinas, 0.5, 8.0),
		"suavidad": _desviar(rng, suavidad, maxf(0.1, suavidad - 0.15), minf(1.0, suavidad + 0.15)),
		"probabilidad_recta": _desviar(rng, probabilidad_recta, 0.0, 1.0),
		"curvatura": _desviar(rng, curvatura, 0.0, 90.0),
	}
	var ruido := FastNoiseLite.new()
	ruido.seed = seed_pista
	ruido.frequency = 1.0
	var puntos: Array[Vector3] = []
	var es_circuito := modo == Modo.CIRCUITO
	var espaciado := largo_pista / float(cantidad_puntos if es_circuito else cantidad_puntos - 1)
	var giro_base := TAU / float(cantidad_puntos) if es_circuito else 0.0
	var posicion := Vector3.ZERO
	var direccion := 0.0
	for i in cantidad_puntos:
		var altura := _altura_en(ruido, TAU * float(i) / float(cantidad_puntos))
		puntos.append(Vector3(posicion.x, altura, posicion.z))
		direccion += giro_base + deg_to_rad(rng.randf_range(-ajustes.curvatura, ajustes.curvatura))
		posicion += Vector3(cos(direccion), 0.0, sin(direccion)) * espaciado
	if es_circuito:
		var error_cierre := posicion
		for i in cantidad_puntos:
			var peso := float(i) / float(cantidad_puntos)
			puntos[i] -= Vector3(error_cierre.x * peso, 0.0, error_cierre.z * peso)
	rectas.clear()
	var ultimo_segmento := cantidad_puntos if modo == Modo.CIRCUITO else cantidad_puntos - 1
	for i in ultimo_segmento:
		if rng.randf() < ajustes.probabilidad_recta:
			rectas.append(i)
	var origen := puntos[0]
	for i in cantidad_puntos:
		puntos[i] -= origen
	var salida := puntos[1] - puntos[0]
	var giro := atan2(salida.z, salida.x)
	for i in cantidad_puntos:
		puntos[i] = puntos[i].rotated(Vector3.UP, giro)
	_agregar_puntos(curva, puntos)
	if resolver_cruces:
		_resolver_cruces(curva, puntos)
	return curva

func _desviar(rng: RandomNumberGenerator, valor: float, minimo: float, maximo: float) -> float:
	var factor := desviacion / 100.0
	return clampf(valor + rng.randf_range(-factor, factor) * (maximo - minimo), minimo, maximo)

func _altura_en(ruido: FastNoiseLite, angulo: float) -> float:
	var muestra := ruido.get_noise_2d(cos(angulo) * ajustes.colinas, sin(angulo) * ajustes.colinas)
	return (muestra * 0.5 + 0.5) * ajustes.variacion_altura

func _agregar_puntos(curva: Curve3D, puntos: Array[Vector3]) -> void:
	curva.clear_points()
	var entradas: Array[Vector3] = []
	var salidas: Array[Vector3] = []
	for i in cantidad_puntos:
		var anterior := puntos[maxi(i - 1, 0)] if modo == Modo.SPRINT else puntos[(i - 1 + cantidad_puntos) % cantidad_puntos]
		var siguiente := puntos[mini(i + 1, cantidad_puntos - 1)] if modo == Modo.SPRINT else puntos[(i + 1) % cantidad_puntos]
		var tangente := (siguiente - anterior) * 0.5 * float(ajustes.suavidad)
		var limite := minf(puntos[i].distance_to(anterior), puntos[i].distance_to(siguiente)) * 0.5
		tangente = tangente.limit_length(limite)
		entradas.append(-tangente)
		salidas.append(tangente)
	for i in rectas:
		var siguiente := (i + 1) % cantidad_puntos
		var cuerda := (puntos[siguiente] - puntos[i]) / 3.0
		var direccion := cuerda.normalized()
		salidas[i] = cuerda
		entradas[i] = -direccion * entradas[i].length()
		entradas[siguiente] = -cuerda
		salidas[siguiente] = direccion * salidas[siguiente].length()
	for i in cantidad_puntos:
		curva.add_point(puntos[i], entradas[i], salidas[i])

func _resolver_cruces(curva: Curve3D, puntos: Array[Vector3]) -> void:
	curva.bake_interval = 5.0
	for intento in 6:
		var muestras := curva.get_baked_points()
		var n := muestras.size()
		if n < 4:
			return
		var margen := ceili(ancho_de_pista / curva.bake_interval) + 1
		var offsets: Array[float] = []
		for k in cantidad_puntos:
			offsets.append(curva.get_closest_offset(puntos[k]))
		var hubo_cambios := false
		for i in n - 1:
			for j in range(i + margen, n - 1):
				if modo == Modo.CIRCUITO and i < margen and j >= n - 1 - margen:
					continue
				var a1 := Vector2(muestras[i].x, muestras[i].z)
				var a2 := Vector2(muestras[i + 1].x, muestras[i + 1].z)
				var b1 := Vector2(muestras[j].x, muestras[j].z)
				var b2 := Vector2(muestras[j + 1].x, muestras[j + 1].z)
				var cruce = Geometry2D.segment_intersects_segment(a1, a2, b1, b2)
				if cruce == null:
					continue
				if absf(muestras[j].y - muestras[i].y) >= altura_puente * 0.9:
					continue
				var inferior := i if muestras[i].y <= muestras[j].y else j
				var superior := j if inferior == i else i
				var altura_necesaria := muestras[inferior].y + altura_puente
				for indice in _segmento_de_control(offsets, float(superior) * curva.bake_interval):
					if puntos[indice].y < altura_necesaria:
						puntos[indice].y = altura_necesaria
						hubo_cambios = true
		if not hubo_cambios:
			return
		_agregar_puntos(curva, puntos)

func _segmento_de_control(offsets: Array[float], objetivo: float) -> Array[int]:
	for k in cantidad_puntos - 1:
		if objetivo >= offsets[k] and objetivo <= offsets[k + 1]:
			return [k, k + 1]
	if modo == Modo.CIRCUITO:
		return [cantidad_puntos - 1, 0]
	return [cantidad_puntos - 1]

func _actualizar_poligonos() -> void:
	pista.polygon = PackedVector2Array([
		Vector2(0.0, 0.5),
		Vector2(ancho_de_pista, 0.5),
		Vector2(ancho_de_pista, 0.0),
		Vector2(0.0, 0.0),
	])
	borde_izq.polygon = PackedVector2Array([
		Vector2(-grosor_borde, 0.0),
		Vector2(0.0, 0.0),
		Vector2(0.0, alto_borde),
		Vector2(-grosor_borde, alto_borde),
	])
	borde_der.polygon = PackedVector2Array([
		Vector2(ancho_de_pista, 0.0),
		Vector2(ancho_de_pista + grosor_borde, 0.0),
		Vector2(ancho_de_pista + grosor_borde, alto_borde),
		Vector2(ancho_de_pista, alto_borde),
	])
	if textura_pista:
		var material := StandardMaterial3D.new()
		material.albedo_texture = textura_pista
		pista.material = material
