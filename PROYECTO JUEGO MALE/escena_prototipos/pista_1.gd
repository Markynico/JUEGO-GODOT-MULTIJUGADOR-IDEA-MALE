@tool
extends Node3D


@onready var pista: CSGPolygon3D = %Pista
@onready var borde_izq: CSGPolygon3D = $Path3D/Bordes
@onready var borde_der: CSGPolygon3D = $Path3D/Bordes2

@export var ancho_de_pista: float = 20.0:
	set(value):
		ancho_de_pista = value
		if is_inside_tree():
			_actualizar()
@export var alto_borde: float = 2.0:
	set(value):
		alto_borde = value
		if is_inside_tree():
			_actualizar()
@export var grosor_borde: float = 1.0:
	set(value):
		grosor_borde = value
		if is_inside_tree():
			_actualizar()

func _ready() -> void:
	_actualizar()

func _actualizar() -> void:
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
