extends RigidBody3D



func _on_body_entered(body: Node) -> void:
	await get_tree().create_timer(2).timeout #para eliminar la pelotita desp de chocar con algo
	queue_free()
