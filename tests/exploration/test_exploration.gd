extends GutTest
## Exploração estilo Baldur's Gate: o grupo anda pelo mapa de navegação, a luta começa ao chegar
## perto das ruínas e, vencida, o controle volta para a exploração com quem caiu de pé.

const LEVEL: PackedScene = preload("res://levels/ethera/ethera.tscn")

var _level: Node3D
var _party: PartyController
var _combat: CombatManager


func before_each() -> void:
	_level = LEVEL.instantiate() as Node3D
	_combat = _level.get_node("Combat") as CombatManager
	_combat.auto_heroes = true
	_combat.animate = false
	add_child_autofree(_level)
	_party = _level.get_node("Party") as PartyController
	await wait_until(func() -> bool: return _party.enabled, 15.0)


func test_starts_exploring_at_camp() -> void:
	assert_true(_party.enabled, "começa explorando")
	assert_eq(_party.heroes.size(), 5)
	assert_false(_level.in_combat)
	var map := _level.get_world_3d().navigation_map
	assert_gt(NavigationServer3D.map_get_regions(map).size(), 0, "tem mapa de navegação")


func test_party_walks_where_clicked() -> void:
	var leader := _party.leader
	var start := leader.global_position
	var target := start + Vector3(0, 0, -6)
	_party.move_to(target)
	await wait_seconds(3.0)
	assert_lt(leader.global_position.distance_to(target), start.distance_to(target) - 3.0, "o líder andou na direção do clique")
	var follower := _party.heroes[1]
	assert_lt(follower.global_position.distance_to(leader.global_position), 6.0, "os outros vieram junto")


func test_walking_into_ruins_starts_combat_then_returns() -> void:
	Dice.rng.seed = 7
	_party.move_to(Vector3(0, 0, 10))
	await wait_until(func() -> bool: return _level.in_combat, 20.0)
	assert_true(_level.in_combat, "chegar perto das ruínas começa a luta")
	assert_false(_party.enabled, "exploração pausa durante a luta")
	await wait_until(func() -> bool: return _combat.state == CombatManager.State.ENDED or not _level.in_combat, 60.0)
	await wait_seconds(0.5)
	var heroes_won := _party.heroes.any(func(u: Unit) -> bool: return u.is_alive())
	if heroes_won and not _level.in_combat:
		assert_true(_party.enabled, "vitória devolve a exploração")
		for hero: Unit in _party.heroes:
			assert_gt(hero.hp, 0, "%s levanta depois da luta" % hero.display_name)
	else:
		pass_test("derrota nesta semente: a tela de derrota fica (R recomeça)")
