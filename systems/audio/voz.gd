class_name Voz
extends RefCounted
## A voz de cada personagem nas falas (D090): o texto aparece no ritmo de quem fala (pausa na vírgula, mais pausa no
## ponto, reticências arrastadas) e cada sílaba solta um somzinho com a vogal da palavra (os voz_<timbre>_<vogal>
## gerados por tools/audio/gerar_vozes.py), no tom da pessoa. Pergunta sobe no fim; grito sai mais alto.
## A caixa de conversa, a fala das cenas e a fala da luta usam `digitar`; quem fala solto na rua usa `balbucio`.

## Perfil de quem fala: timbre (grave, media, suave), tom (multiplica o tom do arquivo), ritmo (multiplica a
## velocidade do texto). *(proposta)*
const PERFIS := {
	"Tico": {"timbre": "media", "tom": 1.18, "ritmo": 1.05},
	"Tika": {"timbre": "suave", "tom": 1.12, "ritmo": 1.15},
	"Seu Brás": {"timbre": "grave", "tom": 0.9, "ritmo": 0.8},
	"Mendigo": {"timbre": "grave", "tom": 1.0, "ritmo": 0.75},
	"Padeiro": {"timbre": "grave", "tom": 0.95, "ritmo": 1.1},
	"Vendedor": {"timbre": "media", "tom": 0.92, "ritmo": 1.15},
	"Carregador": {"timbre": "grave", "tom": 0.84, "ritmo": 0.9},
	"Garoto": {"timbre": "suave", "tom": 1.22, "ritmo": 1.2},
	"Criança": {"timbre": "suave", "tom": 1.38, "ritmo": 1.25},
	"Viúva": {"timbre": "suave", "tom": 0.9, "ritmo": 0.85},
	"Guarda": {"timbre": "grave", "tom": 1.05, "ritmo": 0.95},
	"Capanga da Forja": {"timbre": "grave", "tom": 0.78, "ritmo": 1.0},
	"Laçador da Forja": {"timbre": "media", "tom": 0.82, "ritmo": 1.1},
}
## Quem não fala com voz (narração, bilhete, dica).
const SEM_VOZ: Array[String] = ["", "Dica", "Ordem de carga", "Luta"]
const TIMBRES: Array[String] = ["grave", "media", "suave"]

## Letras por segundo (antes do ritmo da pessoa e da velocidade do texto nas opções).
const LETRAS_POR_SEGUNDO := 40.0
## Pausas (s) depois de cada pontuação, se vem espaço ou o fim da fala depois dela.
const PAUSA_PONTO := 0.34
const PAUSA_VIRGULA := 0.15
const PAUSA_RETICENCIAS := 0.13  # por pontinho
## Uma sílaba a cada tantas letras, e nunca mais perto que isso uma da outra (s).
const LETRAS_POR_SILABA := 3
const SILABA_MIN := 0.085
const VOLUME := -9.0

const ACENTOS := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o",
	"ú": "u", "ü": "u", "y": "i"}


## O perfil de quem fala pelo nome (o herói pelo primeiro nome: "Tico Lirou" é o Tico). Nome desconhecido ganha uma
## voz sorteada pelo nome (a mesma sempre). Vazio = sem voz.
static func perfil(speaker: String) -> Dictionary:
	if SEM_VOZ.has(speaker):
		return {}
	if PERFIS.has(speaker):
		return PERFIS[speaker]
	var first := speaker.get_slice(" ", 0)
	if PERFIS.has(first):
		return PERFIS[first]
	var h := absi(speaker.hash())
	return {"timbre": TIMBRES[h % 3], "tom": 0.85 + float(h / 3 % 8) * 0.05, "ritmo": 0.9 + float(h / 24 % 5) * 0.06}


## O perfil de quem fala solto no mundo (passante, morador): pelo boneco (criança, bárbaro, maga...) e pelo nome.
static func perfil_de(who: Node) -> Dictionary:
	var fig := who.get_node_or_null("Figure")
	var model := String(fig.get("personagem")) if fig else ""
	var oficio := String(fig.get("oficio")) if fig else ""
	var h := absi(String(who.name).hash())
	var jitter := float(h % 7) * 0.03 - 0.09
	if oficio == "crianca" or bool(who.get("crianca")):
		return {"timbre": "suave", "tom": 1.3 + jitter, "ritmo": 1.2}
	match model:
		"Barbarian", "Knight":
			return {"timbre": "grave", "tom": 0.95 + jitter, "ritmo": 1.0}
		"Mage":
			return {"timbre": "suave", "tom": 0.95 + jitter, "ritmo": 1.0}
	return {"timbre": TIMBRES[h % 3], "tom": 1.0 + jitter, "ritmo": 1.0}


## Mostra `label` (Label ou RichTextLabel, com o texto já posto) letra a letra na voz de `speaker`. Termina quando
## acabou de aparecer; `pressa` (Callable -> bool) verdadeiro mostra tudo na hora (o primeiro clique).
static func digitar(label: Control, speaker: String, pressa: Callable = Callable(), velocidade: float = 1.0) -> void:
	var text := _texto(label)
	var total := text.length()
	label.set("visible_characters", 0)
	var tree := label.get_tree()
	if total == 0 or tree == null or DisplayServer.get_name() == "headless":
		label.set("visible_ratio", 1.0)
		return
	var voz := perfil(speaker)
	var cps := LETRAS_POR_SEGUNDO * float(voz.get("ritmo", 1.0)) * velocidade * float(Settings.value("velocidade_texto"))
	var plan := _plano(text)
	var silabas: Array[int] = plan[0]
	var pausas: Dictionary = plan[1]
	var pergunta := text.strip_edges().ends_with("?")
	var grito := text.strip_edges().ends_with("!")
	var shown := 0
	var clock := 0.0
	var next_at := 0.0  # quando a próxima letra aparece
	var last_blip := -1.0
	var blip := 0
	while shown < total:
		if pressa.is_valid() and bool(pressa.call()):
			break
		if not is_instance_valid(label) or not label.is_visible_in_tree():
			return  # a caixa fechou: nada de voz falando sozinha
		await tree.process_frame
		if not is_instance_valid(label) or _texto(label) != text:
			return  # outra fala tomou o lugar desta
		clock += label.get_process_delta_time()
		while shown < total and clock >= next_at:
			if not voz.is_empty() and blip < silabas.size() and silabas[blip] == shown:
				if clock - last_blip >= SILABA_MIN:
					var fim := float(blip) / maxf(1.0, silabas.size() - 1)
					var tom := float(voz["tom"]) * randf_range(0.96, 1.04)
					if pergunta and fim > 0.7:
						tom *= 1.0 + (fim - 0.7) * 0.5  # a pergunta sobe no fim
					elif not pergunta and fim > 0.85:
						tom *= 0.95  # a afirmação cai
					_silaba(String(voz["timbre"]), _vogal(text, shown), tom, VOLUME + (2.0 if grito else 0.0))
					last_blip = clock
				blip += 1
			shown += 1
			next_at += 1.0 / cps + float(pausas.get(shown - 1, 0.0))
		label.set("visible_characters", shown)
	if is_instance_valid(label) and _texto(label) == text:
		label.set("visible_ratio", 1.0)


static func _texto(label: Control) -> String:
	return (label as RichTextLabel).get_parsed_text() if label is RichTextLabel else String(label.get("text"))


## Uma frase solta em cima da cabeça (Fala.say, Missao.shout): umas sílabas no tom da pessoa, de onde ela está.
static func balbucio(who: Node3D, text: String, volume_db: float = -14.0) -> void:
	if who == null or not who.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var voz := perfil_de(who)
	var plan := _plano(text)
	var count := clampi((plan[0] as Array).size(), 2, 7)
	var tree := who.get_tree()
	for i: int in count:
		if not is_instance_valid(who) or not who.is_inside_tree():
			return
		var vogal := "aeiou"[randi() % 5]
		var tom := float(voz["tom"]) * randf_range(0.95, 1.05) * (1.0 + (0.1 if i == count - 1 and text.ends_with("?") else 0.0))
		var som := "voz_%s_%s" % [voz["timbre"], vogal]
		Audio.play_voice_at(som, who.global_position + Vector3.UP * 1.4, tom, volume_db)
		await tree.create_timer(randf_range(0.085, 0.12) / float(voz.get("ritmo", 1.0))).timeout


## Onde caem as sílabas (índices das letras) e as pausas depois de cada pontuação.
static func _plano(text: String) -> Array:
	var silabas: Array[int] = []
	var pausas := {}
	var desde := LETRAS_POR_SILABA  # letras desde a última sílaba (a primeira letra de cada palavra sempre soa)
	var n := text.length()
	for i: int in n:
		var c := text[i]
		var depois := text[i + 1] if i + 1 < n else " "
		if _letra(c):
			if desde >= LETRAS_POR_SILABA or (i == 0 or not _letra(text[i - 1])):
				silabas.append(i)
				desde = 0
			desde += 1
			continue
		desde = LETRAS_POR_SILABA
		if i == n - 1:
			continue  # pontuação no fim: a fala acabou, sem pausa
		match c:
			".":
				pausas[i] = PAUSA_RETICENCIAS if depois == "." or (i > 0 and text[i - 1] == ".") else (PAUSA_PONTO if depois == " " else 0.0)
			"…":
				pausas[i] = PAUSA_RETICENCIAS * 3.0
			"!", "?":
				pausas[i] = PAUSA_PONTO if depois == " " else 0.0
			",", ";", ":":
				pausas[i] = PAUSA_VIRGULA if depois == " " else 0.0
			"—":
				pausas[i] = PAUSA_VIRGULA if i > 0 else 0.0
	return [silabas, pausas]


static func _letra(c: String) -> bool:
	return c.to_lower() != c.to_upper() or c.is_valid_int()


## A vogal da sílaba que começa em i (a primeira vogal dali até o fim da palavra).
static func _vogal(text: String, i: int) -> String:
	for k: int in range(i, mini(i + 4, text.length())):
		var c: String = text[k].to_lower()
		c = String(ACENTOS.get(c, c))
		if "aeiou".contains(c):
			return c
		if not _letra(c):
			break
	return "a" if randf() < 0.5 else "e"


static func _silaba(timbre: String, vogal: String, tom: float, volume_db: float) -> void:
	Audio.play_voice("voz_%s_%s" % [timbre, vogal], tom, volume_db)  # o banco sorteia a variação (_0.._2)
