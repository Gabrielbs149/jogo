extends Node
## O padeiro de briga (D060): o mesmo Barbarian do KayKit da padaria, sem as armas e sem o chapéu de urso, com o
## rolo de massa na mão direita.

const ROLO := "res://assets/kits/polypizza/Food-Kit/Rolling_Pin.glb"


func _ready() -> void:
	var model := get_parent().get_node_or_null("Model") as Node3D
	if model == null:
		return
	for slot: Node in model.find_children("handslot_*", "", true, false):
		for item: Node in slot.find_children("*", "MeshInstance3D", true, false):
			(item as MeshInstance3D).visible = false
	for found: Node in model.find_children("*_Hat", "MeshInstance3D", true, false):
		(found as MeshInstance3D).visible = false
	var hand := model.find_child("handslot_r", true, false) as Node3D
	if hand and ResourceLoader.exists(ROLO):
		var pin := (load(ROLO) as PackedScene).instantiate() as Node3D
		pin.name = "Rolo"
		hand.add_child(pin)
		pin.scale = Vector3.ONE * 1.6
		pin.rotation_degrees = Vector3(0, 0, 90)
