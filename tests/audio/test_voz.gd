extends GutTest
## A voz das falas (D090): o ritmo do texto (pausa na vírgula e no ponto), as sílabas com a vogal da palavra e o
## perfil de cada personagem.


func test_each_character_has_a_voice_and_narration_has_none() -> void:
	assert_eq(Voz.perfil("Tico")["timbre"], "media")
	assert_eq(Voz.perfil("Tico Lirou"), Voz.perfil("Tico"), "o herói pelo primeiro nome")
	assert_eq(Voz.perfil("Seu Brás")["timbre"], "grave")
	assert_gt(float(Voz.perfil("Criança")["tom"]), float(Voz.perfil("Tico")["tom"]), "criança fala mais fino")
	assert_true(Voz.perfil("").is_empty(), "narração sem voz")
	assert_true(Voz.perfil("Ordem de carga").is_empty(), "papel lido sem voz")
	var stranger := Voz.perfil("Fulano de Tal")
	assert_false(stranger.is_empty(), "quem não está na lista ganha uma voz")
	assert_eq(stranger, Voz.perfil("Fulano de Tal"), "sempre a mesma")


func test_every_voice_file_exists() -> void:
	for timbre: String in Voz.TIMBRES:
		for vogal: String in ["a", "e", "i", "o", "u"]:
			assert_true(Audio.has_sound("voz_%s_%s" % [timbre, vogal]), "voz_%s_%s" % [timbre, vogal])


func test_punctuation_pauses() -> void:
	var text := "Tá bom, mas fica paradinho. Senão... já era!"
	var plan := Voz._plano(text)
	var pausas: Dictionary = plan[1]
	assert_almost_eq(float(pausas.get(text.find(","), 0.0)), Voz.PAUSA_VIRGULA, 0.001, "vírgula")
	assert_almost_eq(float(pausas.get(text.find("."), 0.0)), Voz.PAUSA_PONTO, 0.001, "ponto")
	var dots := text.find("...")
	for k: int in 3:
		assert_almost_eq(float(pausas.get(dots + k, 0.0)), Voz.PAUSA_RETICENCIAS, 0.001, "reticências, ponto a ponto")
	assert_false(pausas.has(text.length() - 1), "a pontuação do fim não espera nada")


func test_syllables_follow_the_words() -> void:
	var text := "Oi, pequeno"
	var silabas: Array = Voz._plano(text)[0]
	assert_true(silabas.has(0), "a primeira letra soa")
	assert_true(silabas.has(text.find("p")), "cada palavra começa com sílaba")
	assert_false(silabas.has(2), "vírgula não soa")
	assert_eq(Voz._vogal("Moço", 0), "o")
	assert_eq(Voz._vogal("Pão", 0), "a", "acento vira a vogal")
	assert_eq(Voz._vogal("é", 0), "e")
