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


## O crash do pregão (29/10): quem fala na rua pode ser Morador (sem "crianca"), Passante ou alguém sem Figure.
func test_street_voices_from_anyone() -> void:
	var morador := Node3D.new()
	morador.set_script(load("res://world/vida/morador.gd"))
	var fig := Node3D.new()
	fig.name = "Figure"
	fig.set_script(load("res://world/figurante.gd"))
	morador.add_child(fig)
	add_child_autofree(morador)
	fig.set("personagem", "Barbarian")
	assert_eq(Voz.perfil_de(morador)["timbre"], "grave", "vendedor bárbaro, voz grossa")
	fig.set("oficio", "crianca")
	assert_eq(Voz.perfil_de(morador)["timbre"], "suave", "criança pelo ofício")
	var passante := Passante.new()
	passante.crianca = true
	add_child_autofree(passante)
	assert_eq(Voz.perfil_de(passante)["timbre"], "suave", "criança da rua")
	var sem_boneco := Node3D.new()
	add_child_autofree(sem_boneco)
	assert_false(Voz.perfil_de(sem_boneco).is_empty(), "sem boneco também tem voz")
	Voz.balbucio(sem_boneco, "Ei!")
	Fala.say(morador, "Peixe! Peixe fresco!")
	Missao.shout(sem_boneco, "Pega ele!")
	await wait_seconds(0.3)
	assert_true(true, "nada travou")
