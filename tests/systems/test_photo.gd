extends GutTest
## A foto gasta filme, revela os Revealable durante o negativo, guarda no álbum e esconde de novo.

const FIGURE_SCENE: PackedScene = preload("res://actors/figure/figure.tscn")

var _player: Player
var _figure: Revealable


func before_each() -> void:
	_player = TestWorld.build(self)
	_figure = FIGURE_SCENE.instantiate() as Revealable
	_figure.caption = "Alguém atrás de mim."
	_player.get_parent().add_child(_figure)
	_figure.global_position = _player.global_position + Vector2(-30, 0)
	Photo.film = Photo.film_capacity
	Photo.photos.clear()


func test_figure_hidden_until_photo() -> void:
	await wait_process_frames(2)
	assert_false(_figure.visible)


func test_photo_reveals_then_hides() -> void:
	await wait_physics_frames(5)
	Photo.take()
	# Tempo, não frames: sem janela os frames correm bem mais rápido que 60/s
	await wait_seconds(0.3)
	assert_true(Photo.is_shooting(), "foto em andamento")
	assert_true(_figure.visible, "figura aparece no negativo")
	assert_eq(Photo.film, Photo.film_capacity - 1, "gastou um filme")
	await wait_seconds(Photo.negative_hold + Photo.negative_dissolve + 0.5)
	assert_false(Photo.is_shooting(), "terminou")
	assert_false(_figure.visible, "sumiu de novo")
	assert_eq(Screen.negative, 0.0)


func test_photo_goes_to_album_with_caption() -> void:
	await wait_physics_frames(5)
	Photo.take()
	await wait_seconds(Photo.negative_hold + Photo.negative_dissolve + 0.5)
	assert_eq(Photo.photos.size(), 1)
	var captions: PackedStringArray = Photo.photos[0]["captions"]
	assert_has(captions, "Alguém atrás de mim.")


func test_no_film_no_photo() -> void:
	Photo.film = 0
	Photo.take()
	await wait_process_frames(3)
	assert_false(Photo.is_shooting())
	assert_true(Dialogue.is_open(), "avisa que acabou o filme")
	TestWorld.press("interact")
	await wait_process_frames(3)
	TestWorld.press("interact")
	await wait_process_frames(3)
