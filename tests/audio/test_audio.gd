extends GutTest
## Som (D034): todo nome usado no jogo acha arquivo, e o chão de Arandu dá o passo certo.

const USED: Array[String] = ["passo_grama", "passo_pedra", "passo_terra", "passo_areia", "golpe", "impacto", "aparar", "esquiva",
	"queda", "qte_perfeito", "qte_bom", "qte_errou", "clique", "passar_mouse", "ler", "conversar", "viajar", "descansar",
	"turno", "fala", "vitoria", "derrota"]


func test_every_sound_used_exists() -> void:
	for sound: String in USED:
		assert_true(Audio.has_sound(sound), sound)


func test_variations_are_grouped() -> void:
	assert_eq((Audio.get("_banks")["passo_grama"] as Array).size(), 5, "5 passos de grama para sortear")


func test_music_files_load_and_loop() -> void:
	for music: String in ["arandu", "ethera", "batalha"]:
		var stream: AudioStream = Audio.call("_stream", "musica", music)
		assert_not_null(stream, music)
		assert_true(stream.get("loop"), music + " em laço")


func test_arandu_floor_types() -> void:
	Level.editing = true
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Level
	add_child_autofree(level)
	assert_eq(level.surface_at(Vector3(0, 0, 6)), "pedra", "praça é de pedra")
	assert_eq(level.surface_at(Vector3(44, 0, 20)), "pedra", "a rua do anel é de pedra")
	assert_eq(level.surface_at(Vector3(0, 0, -100)), "terra", "a estrada lá fora é de terra")
	assert_eq(level.surface_at(Vector3(110, 0, 110)), "grama", "fora da muralha é grama")
	assert_eq(level.musica, "arandu")
	Level.editing = false
