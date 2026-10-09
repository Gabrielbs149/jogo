extends GutTest
## Arandu viva (D060) e as casas de entrar (D061): gente andando, moradores com horário, bichos, pombos, balões,
## a briga com o padeiro (o depois) e os interiores que carregam quando você chega perto.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level


func _open(hour: float = 10.0, flags: Dictionary = {}) -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge({"prologo.etapa": "saiu", "comida.comecou": true})
	Game.flags.merge(flags)
	Game.items.clear()
	Game.hora = hour
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child_autofree(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 25.0)


func test_people_walk_around_and_go_home_at_night() -> void:
	await _open(10.0)
	var vida := _level.get_node("Vida") as Vida
	await wait_until(func() -> bool: return vida.people.size() > 0, 10.0)
	assert_eq(vida.people.size(), vida.quantidade + vida.criancas)
	var spot := vida.pick_spot(vida.people[0])
	assert_false(spot.is_empty(), "sempre tem para onde ir de dia")
	var walking := 0
	for p: Passante in vida.people:
		if p.estado == Passante.Estado.INDO:
			walking += 1
	assert_gt(walking, 3, "tem gente andando")
	# de noite: quem já devia estar dormindo volta para casa
	var person := vida.people[0]
	person.dorme = 20.0
	_level.ciclo.jump_to(23.0)
	person.call("_choose_next")
	assert_eq(String(person.ponto.get("tipo", "")), "casa")


func test_people_walk_on_the_ground() -> void:
	# o mapa de navegação fica ~0,5 m acima do chão: quem andava na altura dele flutuava
	await _open(10.0)
	var vida := _level.get_node("Vida") as Vida
	await wait_seconds(2.0)
	var space := _level.get_world_3d().direct_space_state
	var checked := 0
	for p: Passante in vida.people:
		if not p.visible:
			continue
		var from := p.global_position + Vector3.UP * 0.9
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1))
		if hit.is_empty():
			continue
		assert_almost_eq(p.global_position.y, (hit["position"] as Vector3).y, 0.12, "%s com os pés no chão" % p.name)
		checked += 1
	assert_gt(checked, 5)


func test_new_townsfolk_models_walk_wave_and_fit_in() -> void:
	# D063: os modelos da Quaternius traduzem as animações do jogo e ficam do tamanho dos bonecos do KayKit
	for model: String in Figurante.EXTRA:
		var fig := Figurante.new()
		add_child_autofree(fig)
		fig.personagem = model
		for anim: String in ["Idle", "Walking_A", "Running_A", "Cheer"]:
			assert_true(fig.can_play(anim), "%s faz %s" % [model, anim])
		fig.animacao = "Walking_A"
		assert_true(fig.player().is_playing(), "%s anda" % model)
		var model_node := fig.get_node("Modelo") as Node3D
		var height := Figurante._height_of(model_node) * model_node.scale.y
		assert_almost_eq(height, Figurante._kaykit_reference() * 1.1, 0.3, "%s com altura de gente da cidade" % model)
	var stiff := Figurante.new()
	add_child_autofree(stiff)
	stiff.personagem = "Fazendeiro"
	assert_false(stiff.can_play("Lie_Idle"), "os novos não deitam (quem deita fica do KayKit)")


func test_residents_keep_their_hours() -> void:
	await _open(12.0)
	var seller := _level.get_node("Crowd/Vendedor2") as Morador
	assert_not_null(seller, "a banca 2 ganhou vendedor")
	await wait_until(func() -> bool: return seller.visible, 3.0)
	assert_true(seller.visible, "meio-dia: na banca")
	_level.ciclo.jump_to(22.0)
	await wait_until(func() -> bool: return not seller.visible, 3.0)
	assert_false(seller.visible, "de noite foi para casa")
	assert_false(seller.pregao.is_empty(), "vendedor grita pregão")


func test_animals_and_pigeons_are_alive() -> void:
	await _open(10.0)
	var dog := _level.get_node("Animals/Shiba") as Bicho
	assert_not_null(dog)
	assert_eq(dog.jeito, Bicho.Jeito.AMIGO)
	var flock := _level.get_node("Pombos/BandoPraca") as Pombos
	assert_not_null(flock)
	_level.player.global_position = flock.global_position + Vector3(0, 0.1, 0)
	await wait_physics_frames(3)
	assert_true(flock.get("_flying"), "chegou perto: o bando voa")


func test_emote_icons_are_drawn() -> void:
	for kind: String in Emote.KINDS:
		var tex := Emote.texture_for(kind)
		assert_not_null(tex, kind)
		assert_eq(tex.get_size(), Vector2(Emote.SIZE, Emote.SIZE))


func test_winning_the_fight_with_the_baker_gets_bread() -> void:
	await _open(10.0, {"padaria.briga": "pendente", "luta.briga_padeiro": "venceu", "padaria.estado": "expulso"})
	await wait_until(func() -> bool: return Game.flag("padaria.briga", "") == "venceu", 5.0)
	assert_eq(Game.flag("padaria.jeito"), "brigou")
	assert_true(Game.has_item("comida"), "ele joga um pão")


func test_losing_the_fight_leaves_you_thrown_out() -> void:
	await _open(10.0, {"padaria.briga": "pendente", "luta.briga_padeiro": "perdeu", "padaria.estado": "expulso"})
	await wait_until(func() -> bool: return Game.flag("padaria.briga", "") == "perdeu", 5.0)
	assert_false(Game.has_item("comida"))
	assert_eq(Game.flag("padaria.estado"), "expulso")


func test_baker_fight_is_set_up_without_death() -> void:
	var fight: Dictionary = MissaoPadaria.BRIGA
	assert_true(fight["nao_letal"])
	assert_true(ResourceLoader.exists(String(fight["arena"])), "a arena de rua existe")
	assert_true(ResourceLoader.exists(String((fight["enemies"] as Array)[0])), "o padeiro furioso existe")


func test_every_house_has_an_interior_that_loads_nearby() -> void:
	await _open(12.0)
	var count := 0
	for child: Node in _level.get_node("Buildings").get_children():
		if not child.has_meta("celulas"):
			continue
		var loader := child.get_node_or_null("Interior") as InteriorSobDemanda
		assert_not_null(loader, "%s tem interior" % child.name)
		if loader:
			assert_true(ResourceLoader.exists(loader.cena), "%s: cena do interior" % child.name)
			count += 1
	assert_gt(count, 80, "quase todas as casas são de entrar")
	# a taverna: carregada, tem gente e móveis
	var tavern := _level.get_node("Buildings/Taverna/Interior") as InteriorSobDemanda
	tavern.load_now()
	assert_true(tavern.loaded())
	var people := tavern.find_children("Morador*", "", true, false)
	assert_gt(people.size(), 3, "taverna com taverneiro, fregueses e o bardo")
	var bodies := tavern.find_children("Colisao*", "StaticBody3D", true, false)
	assert_gt(bodies.size(), 4, "móveis com colisão")


func test_house_doors_are_open() -> void:
	await _open(12.0)
	var space := _level.get_world_3d().direct_space_state
	var checked := 0
	for name: String in ["Casa", "Casa_barro2", "Casa_estreita3", "Casa_grande4", "Estalagem", "CasaDoMercador"]:
		var b := _level.get_node_or_null("Buildings/" + name) as Node3D
		if b == null:
			continue
		var cells: Vector2i = b.get_meta("celulas")
		var door_x := -cells.x + 1.0 + 2.0 * int(b.get_meta("porta", 0))
		var from := b.global_transform * Vector3(door_x, 1.0, -cells.y - 1.0)
		var to := b.global_transform * Vector3(door_x, 1.0, -cells.y + 0.7)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		assert_true(hit.is_empty(), "%s: a porta está aberta" % name)
		checked += 1
	assert_gt(checked, 4)
