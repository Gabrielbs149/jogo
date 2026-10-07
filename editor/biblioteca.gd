class_name EditorLibrary
extends RefCounted
## Biblioteca do editor de mapas (D042): todas as peças do jogo organizadas em categorias, com nome em
## português, dica, o grupo da fase onde entram, a escala certa de cada pacote e se são "estrutura"
## (prédios, muros: encaixam na grade pela pegada e ficam no chão) ou "objeto" (podem ir em cima de mesa, balcão...).
## Peça nova em world/props aparece sozinha em "Outras peças"; peça nova num kit aparece na categoria do kit.

const PROPS := "res://world/props/"
const ICONS := "res://editor/icones/"
## Acervo local (D043): tudo o que foi baixado do poly.pizza, fora do Git (tools/art/montar_acervo.py).
const ACERVO := "res://assets/acervo/"
const ACERVO_CATEGORY := "Acervo poly.pizza"

## Peças prontas (world/props): chave -> [nome, categoria, grupo da fase, varia ao colocar, estrutura, dica]
const PIECES: Dictionary[String, Array] = {
	# prédios
	"casa": ["Casa", "Prédios", "Buildings", false, true, "Casa de reboco (6 x 6 m)"],
	"casa_barro": ["Casa de pedra", "Prédios", "Buildings", false, true, "Casa de pedra (6 x 6 m)"],
	"casa_estreita": ["Casa estreita", "Prédios", "Buildings", false, true, "Dois andares, estreita (4 x 6 m)"],
	"casa_estreita_pedra": ["Estreita de pedra", "Prédios", "Buildings", false, true, "Estreita, pedra embaixo (4 x 6 m)"],
	"casa_longa": ["Casa comprida", "Prédios", "Buildings", false, true, "Térrea comprida (6 x 8 m)"],
	"casa_grande": ["Sobrado", "Prédios", "Buildings", false, true, "Sobrado de pedra e reboco (8 x 8 m)"],
	"casa_grande_barro": ["Sobrado enxaimel", "Prédios", "Buildings", false, true, "Sobrado com enxaimel (8 x 8 m)"],
	"sobrado_longo": ["Sobrado comprido", "Prédios", "Buildings", false, true, "Sobrado comprido (6 x 8 m)"],
	"casa_enxaimel": ["Casa enxaimel azul", "Prédios", "Buildings", false, true, "Casa alta de enxaimel, telhado azul"],
	"casa_enxaimel2": ["Casa enxaimel", "Prédios", "Buildings", false, true, "Casa de enxaimel com sacada"],
	"padaria": ["Padaria", "Prédios", "Buildings", false, true, "Padaria com balcão, pães e forno (dá para entrar)"],
	"estalagem": ["Estalagem", "Prédios", "Buildings", false, true, "Estalagem (hotel) com placa"],
	"ferreiro": ["Ferreiro", "Prédios", "Buildings", false, true, "Ferraria com bigorna e forja acesa"],
	"estabulo": ["Estábulo", "Prédios", "Buildings", false, true, "Estábulo com cercado, cavalos e feno"],
	"moinho": ["Moinho", "Prédios", "Buildings", false, true, "Moinho de vento com sacos de farinha"],
	"serraria": ["Serraria", "Prédios", "Buildings", false, true, "Serraria com toras"],
	"guarita": ["Guarita", "Prédios", "Buildings", false, true, "Guarita de pedra com armas e boneco de treino"],
	"torre_sino": ["Torre do sino", "Prédios", "Buildings", false, true, "Torre alta com sino"],
	"marquise": ["Marquise", "Prédios", "Buildings", false, true, "Cobertura de madeira presa na parede (o lado de trás encosta na parede)"],
	"casa_pedra": ["Casa de pedra escura", "Prédios", "Buildings", false, true, "Casa alta de pedra escura com telhado de ardósia"],
	"gazebo": ["Gazebo", "Praça e feira", "Plaza", false, true, "Coreto de madeira"],
	# fazenda (D044)
	"celeiro": ["Celeiro", "Fazenda", "Buildings", false, true, "Celeiro vermelho (10 x 11 m)"],
	"celeiro_grande": ["Celeiro grande", "Fazenda", "Buildings", false, true, "Celeiro alto de dois andares"],
	"celeiro_pequeno": ["Celeiro pequeno", "Fazenda", "Buildings", false, true, "Celeiro pequeno"],
	"celeiro_aberto": ["Celeiro aberto", "Fazenda", "Buildings", false, true, "Galpão aberto"],
	"silo": ["Silo", "Fazenda", "Buildings", false, true, "Silo de grãos (10 m)"],
	"silo_casa": ["Silo com depósito", "Fazenda", "Buildings", false, true, "Silo com casinha"],
	"moinho_torre": ["Moinho de pás", "Fazenda", "Buildings", false, true, "Moinho de torre de pedra"],
	"galinheiro": ["Galinheiro", "Fazenda", "Buildings", false, true, "Galinheiro"],
	"cerca_fazenda": ["Cerca de fazenda", "Fazenda", "Props", false, true, "Cerca de madeira de 6 m"],
	"cerca_fazenda2": ["Cerca baixa", "Fazenda", "Props", false, true, "Cerca de duas tábuas, 6 m"],
	"trigo": ["Trigo", "Fazenda", "Gardens", true, false, "Moita de trigo (sem colisão)"],
	"aboboral": ["Abóboras", "Fazenda", "Gardens", true, false, "Abóboras no chão (sem colisão)"],
	"feno": ["Feno", "Fazenda", "Props", false, false, "Fardo de feno"],
	"sacos": ["Sacos", "Fazenda", "Props", false, false, "Sacos de farinha"],
	"fardos": ["Fardos", "Fazenda", "Props", false, false, "Fardos amarrados"],
	"carroca_quebrada": ["Carroça quebrada", "Fazenda", "Props", false, true, "Carroça velha, sem roda"],
	"torre_vigia": ["Torre de vigia", "Muralha", "Buildings", false, true, "Torre de vigia de madeira (9 m)"],
	"estatua_cervo": ["Estátua do cervo", "Praça e feira", "Plaza", false, true, "Cervo de bronze num pedestal"],
	# cemitério (D044)
	"lapide": ["Lápide", "Cemitério", "Props", true, false, "Lápide com caveira"],
	"lapide2": ["Lápide grande", "Cemitério", "Props", true, false, "Lápide grande"],
	"tumulo": ["Túmulo", "Cemitério", "Props", true, false, "Túmulo"],
	"tumulo_rachado": ["Túmulo rachado", "Cemitério", "Props", true, false, "Túmulo velho e rachado"],
	"cruz": ["Cruz", "Cemitério", "Props", true, false, "Cruz de madeira"],
	"cruz2": ["Cruz torta", "Cemitério", "Props", true, false, "Cruz de madeira torta"],
	"cripta": ["Cripta", "Cemitério", "Buildings", false, true, "Cripta de pedra"],
	"grade_cemiterio": ["Grade do cemitério", "Cemitério", "Props", false, true, "Grade de ferro de 3 m"],
	"grade_cemiterio_quebrada": ["Grade quebrada", "Cemitério", "Props", false, true, "Grade de ferro quebrada, 3 m"],
	"pilar_grade": ["Pilar da grade", "Cemitério", "Props", false, true, "Pilar de pedra para a grade"],
	"portao_cemiterio": ["Portão do cemitério", "Cemitério", "Props", false, true, "Arco de pedra com portão de ferro"],
	"santuario": ["Santuário", "Cemitério", "Props", false, true, "Pilar de oração"],
	"santuario_velas": ["Santuário com velas", "Cemitério", "Props", false, true, "Pilar de oração com velas"],
	"caixao": ["Caixão", "Cemitério", "Props", false, true, "Caixão de madeira"],
	"velas": ["Velas", "Cemitério", "Props", false, false, "Velas acesas"],
	"pinheiro_outono": ["Pinheiro de outono", "Cemitério", "Trees", true, false, "Pinheiro alaranjado"],
	"pinheiro_outono2": ["Pinheiro de outono alto", "Cemitério", "Trees", true, false, "Pinheiro alaranjado alto"],
	"arvore_seca_galhos": ["Árvore seca de galhos", "Cemitério", "Trees", true, false, "Árvore morta"],
	"caminho_pedras": ["Pedras de caminho", "Cemitério", "Props", true, false, "Pedras chatas de caminho (sem colisão)"],
	"poste_lanterna": ["Poste com lanterna", "Luzes", "Lights", false, false, "Poste de madeira com lanterna pendurada (acesa)"],
	# muralha
	"muro": ["Muro", "Muralha", "Walls", false, true, "Muro de pedra de 6 m"],
	"torre": ["Torre", "Muralha", "Walls", false, true, "Torre de muralha (4 x 4 m)"],
	"portao": ["Portão", "Muralha", "Walls", false, true, "Arco de passagem entre muros"],
	"grade_ferro": ["Grade de ferro", "Muralha", "Props", false, true, "Grade de ferro de 2 m"],
	"cerca": ["Cerca", "Muralha", "Props", false, true, "Cerca de madeira de 2 m"],
	# praça e feira
	"chafariz": ["Chafariz", "Praça e feira", "Plaza", false, true, "Chafariz grande com água, numa plataforma de degraus"],
	"poco": ["Poço", "Praça e feira", "Buildings", false, true, "Poço de pedra"],
	"poco_telhado": ["Poço com telhado", "Praça e feira", "Buildings", false, true, "Poço de pedra com telhadinho"],
	"estatua": ["Estátua", "Praça e feira", "Plaza", false, true, "Estátua de guerreiro num pedestal"],
	"canteiro": ["Canteiro", "Praça e feira", "Plaza", false, true, "Canteiro de pedra com árvore e flores"],
	"banco_praca": ["Banco da praça", "Praça e feira", "Plaza", false, false, "Banco de madeira (quem senta: figurante 'Sit_Chair_Idle')"],
	"pelourinho": ["Pelourinho", "Praça e feira", "Plaza", false, true, "Pelourinho de madeira"],
	"banca_frutas": ["Banca de frutas", "Praça e feira", "Market", false, true, "Banca com caixotes de maçã, pera e limão"],
	"banca_verduras": ["Banca de verduras", "Praça e feira", "Market", false, true, "Banca com couve, cenoura e cebola"],
	"banca_paes": ["Banca de pães", "Praça e feira", "Market", false, true, "Banca com pães, tortas e croissants"],
	"banca_peixe": ["Banca de peixe", "Praça e feira", "Market", false, true, "Banca com caixotes de peixe"],
	"carroca_feira": ["Carroça da feira", "Praça e feira", "Market", false, true, "Carroça com frutas e abóboras"],
	"barraca": ["Barraca", "Praça e feira", "Market", false, true, "Barraca de feira simples"],
	"barraca_carroca": ["Carrinho de vendedor", "Praça e feira", "Market", false, true, "Carrinho de vendedor"],
	"placa_rua1": ["Placa de direção", "Praça e feira", "Plaza", false, false, "Placa com setas"],
	"placa_rua2": ["Placa de direção 2", "Praça e feira", "Plaza", false, false, "Placa com setas"],
	"placa_rua3": ["Placa de aviso", "Praça e feira", "Plaza", false, false, "Placa de madeira"],
	"horta": ["Horta", "Praça e feira", "Gardens", false, false, "Fileira de couve, cenoura e abóbora"],
	# luz
	"poste": ["Poste", "Luzes", "Lights", false, false, "Poste de ferro com lanterna acesa"],
	"lanterna": ["Lanterna de parede", "Luzes", "Lights", false, false, "Lanterna acesa (encoste o lado de trás na parede)"],
	"tocha": ["Tocha", "Luzes", "Lights", false, false, "Tocha acesa"],
	"luz": ["Luz", "Luzes", "Lights", false, false, "Luz sozinha, que ilumina em volta"],
	"fogueira": ["Fogueira", "Gente e história", "Places", false, false, "Fogueira: F descansa e enche a vida"],
	# natureza
	"arvore": ["Árvore", "Natureza", "Trees", true, false, "Árvore comum (cada uma sai um pouco diferente)"],
	"arvore_pequena": ["Árvore pequena", "Natureza", "Trees", true, false, "Árvore pequena"],
	"pinheiro": ["Pinheiro", "Natureza", "Trees", true, false, "Pinheiro"],
	"arvore_torta": ["Árvore torta", "Natureza", "Trees", true, false, "Árvore grande e retorcida"],
	"arvore_morta": ["Árvore seca", "Natureza", "Trees", true, false, "Árvore seca, sem folhas"],
	"tronco_seco": ["Tronco seco", "Natureza", "Trees", true, false, "Tronco morto, em pé"],
	"toco": ["Toco", "Natureza", "Trees", true, false, "Toco de árvore"],
	"arbusto": ["Arbusto", "Natureza", "Trees", true, false, "Arbusto (sem colisão)"],
	"arbusto_baixo": ["Arbusto florido", "Natureza", "Trees", true, false, "Arbusto com flores (sem colisão)"],
	"suculenta": ["Planta", "Natureza", "Trees", true, false, "Planta de folhas grandes (sem colisão)"],
	"samambaia": ["Samambaia", "Natureza", "Trees", true, false, "Samambaia (sem colisão)"],
	"grama": ["Grama alta", "Natureza", "Trees", true, false, "Tufo de grama alta (sem colisão)"],
	"flores": ["Flores", "Natureza", "Trees", true, false, "Flores (sem colisão)"],
	"rocha": ["Rocha", "Natureza", "Rocks", true, false, "Rocha média"],
	"rocha_grande": ["Rocha grande", "Natureza", "Rocks", true, true, "Rocha grande"],
	"penhasco": ["Penhasco", "Natureza", "Rocks", true, true, "Rochedo enorme"],
	"pedregulhos": ["Pedras redondas", "Natureza", "Rocks", true, false, "Pedras no chão (sem colisão)"],
	"pedras": ["Pedras chatas", "Natureza", "Rocks", true, false, "Pedras chatas no chão (sem colisão)"],
	"pedrinhas": ["Pedrinha", "Natureza", "Rocks", true, false, "Pedrinha solta (sem colisão)"],
	"pilar": ["Pilar de arenito", "Natureza", "Ruins", false, true, "Pilar de ruína"],
	# objetos
	"caixote": ["Caixote", "Objetos", "Props", false, false, "Caixote de madeira"],
	"caixote_alto": ["Caixote grande", "Objetos", "Props", false, false, "Caixote grande"],
	"caixote_macas": ["Caixa de maçãs", "Objetos", "Props", false, false, "Caixinha com maçãs"],
	"barril": ["Barril", "Objetos", "Props", false, false, "Barril"],
	"barril_vinho": ["Barril de maçãs", "Objetos", "Props", false, false, "Barril cheio de maçãs"],
	"barris": ["Suporte de barris", "Objetos", "Props", false, false, "Barris deitados num suporte"],
	"balde": ["Balde", "Objetos", "Props", false, false, "Balde de madeira"],
	"cesto": ["Saco", "Objetos", "Props", false, false, "Saco de pano"],
	"jarro": ["Panela", "Objetos", "Props", false, false, "Panela de barro"],
	"vaso": ["Vaso", "Objetos", "Props", false, false, "Vaso de cerâmica"],
	"banquinho": ["Banquinho", "Objetos", "Props", false, false, "Banquinho"],
	"cadeira": ["Cadeira", "Objetos", "Props", false, false, "Cadeira"],
	"banco": ["Banco", "Objetos", "Props", false, false, "Banco de madeira"],
	"mesa": ["Mesa", "Objetos", "Props", false, false, "Mesa grande"],
	"bau": ["Baú", "Objetos", "Props", false, false, "Baú de madeira"],
	"bigorna": ["Bigorna", "Objetos", "Props", false, false, "Bigorna de ferreiro"],
	"bancada": ["Bancada", "Objetos", "Props", false, false, "Bancada de trabalho"],
	"caldeirao": ["Caldeirão", "Objetos", "Props", false, false, "Caldeirão"],
	"boneco_treino": ["Boneco de treino", "Objetos", "Props", false, false, "Boneco de palha (também serve de espantalho)"],
	"carroca": ["Carroça", "Objetos", "Props", false, true, "Carroça de madeira"],
	"estandarte": ["Estandarte", "Objetos", "Props", false, false, "Estandarte de pano"],
	"pao": ["Pão", "Objetos", "Props", false, false, "Pão (a metade fica escondida, para cenas)"],
	"meio_pao": ["Meio pão", "Objetos", "Props", false, false, "Metade de um pão"],
	# animais
	"cavalo": ["Cavalo", "Animais", "Animals", false, false, "Cavalo"],
	"vaca": ["Vaca", "Animais", "Animals", false, false, "Vaca"],
	"porco": ["Porco", "Animais", "Animals", false, false, "Porco"],
	"galinha": ["Galinha", "Animais", "Animals", true, false, "Galinha"],
	"cachorro": ["Cachorro", "Animais", "Animals", false, false, "Cachorro"],
	"gato": ["Gato", "Animais", "Animals", false, false, "Gato"],
	# gente e história
	"morador": ["Morador", "Gente e história", "People", false, false, "Pessoa da cidade: F mostra a fala. Personagem e animação no painel"],
	"inscricao": ["Inscrição", "Gente e história", "Ruins", false, false, "Pedra com inscrição: F mostra o texto"],
	"saida": ["Saída", "Gente e história", "Places", false, true, "Arco: F leva para outra fase (escolha qual no painel)"],
	"lugar_heroi": ["Herói esperando", "Gente e história", "HeroSpots", false, false, "Onde um herói espera para entrar no grupo"],
	# inimigos
	"grupo_escaravelhos": ["Escaravelhos", "Inimigos", "Encounters", false, false, "2 Escaravelhos de Cinza: encostar começa a luta"],
	"grupo_sentinela": ["Sentinela", "Inimigos", "Encounters", false, false, "Sentinela Estelar: encostar começa a luta"],
	"grupo_guardiao": ["Último Guardião", "Inimigos", "Encounters", false, false, "O chefe de Ethera"],
}

## Pastas de modelos soltos: pasta -> [categoria, grupo da fase, escala, estrutura]
const KITS: Dictionary[String, Array] = {
	"res://assets/kits/quaternius/vila/": ["Peças de casa (kit)", "Buildings", 1.0, true],
	"res://assets/kits/quaternius/objetos/": ["Objetos do kit", "Props", 1.0, false],
	"res://assets/kits/quaternius/natureza/": ["Natureza do kit", "Trees", 1.0, false],
	"res://assets/kits/polypizza/Medieval-Village-Pack/": ["Vila medieval (peças)", "Buildings", 3.0, true],
	"res://assets/kits/polypizza/Modular-Dungeons-Pack/": ["Masmorra", "Dungeon", 1.0, true],
	"res://assets/kits/polypizza/Ultimate-RPG-Items-Bundle/": ["Itens de RPG", "Props", 0.5, false],
	"res://assets/kits/polypizza/Food-Kit/": ["Comida", "Props", 0.5, false],
	"res://assets/kits/polypizza/Baked-Goods/": ["Comida", "Props", 0.45, false],
	"res://assets/kits/polypizza/Low-Poly-Outdoor-Garden-Decorations/": ["Jardim", "Plaza", 1.0, false],
	"res://assets/kits/polypizza/Signs-pack/": ["Praça e feira", "Plaza", 1.2, false],
	"res://assets/kits/polypizza/Medieval-Torture-Devices/": ["Masmorra", "Dungeon", 1.3, false],
	"res://assets/kits/polypizza/Witch-cottage-pack/": ["Jardim", "Plaza", 1.0, false],
}

## Ordem das categorias na tela (o que não estiver aqui vem depois).
const ORDER: Array[String] = ["Prédios", "Muralha", "Praça e feira", "Fazenda", "Cemitério", "Luzes", "Natureza", "Objetos", "Animais", "Gente e história", "Inimigos",
	"Peças de casa (kit)", "Vila medieval (peças)", "Masmorra", "Objetos do kit", "Natureza do kit", "Comida", "Itens de RPG", "Jardim", "Outras peças",
	ACERVO_CATEGORY]

## Palavras dos nomes dos kits em português (para "Wall_Plaster_Door_Round" virar "Parede reboco porta redonda").
const WORDS: Dictionary[String, String] = {
	"wall": "parede", "floor": "piso", "roof": "telhado", "door": "porta", "doorframe": "batente", "window": "janela", "windowshutters": "veneziana",
	"stairs": "escada", "stair": "escada", "corner": "quina", "balcony": "sacada", "overhang": "beiral", "prop": "", "plaster": "reboco",
	"brick": "tijolo", "unevenbrick": "pedra", "redbrick": "tijolo vermelho", "wood": "madeira", "wooddark": "madeira escura", "woodlight": "madeira clara",
	"round": "redonda", "flat": "reta", "straight": "reta", "wide": "larga", "thin": "fina", "half": "meia", "exterior": "fora", "interior": "dentro",
	"big": "grande", "small": "pequena", "open": "aberta", "closed": "fechada", "front": "frente", "side": "lado", "long": "comprida", "short": "curta",
	"chimney": "chaminé", "crate": "caixote", "wagon": "carroça", "fence": "cerca", "support": "suporte", "vine": "trepadeira", "metalfence": "grade",
	"woodenfence": "cerca", "roundtile": "telha", "roundtiles": "telhas", "tower": "torre", "log": "tora", "arch": "arco", "platform": "plataforma",
	"rails": "corrimão", "solid": "maciça", "simple": "simples", "cover": "tampa", "holecover": "tampa", "border": "borda", "exteriorborder": "borda",
	"tree": "árvore", "commontree": "árvore", "deadtree": "árvore seca", "twistedtree": "árvore torta", "pine": "pinheiro", "bush": "arbusto",
	"common": "", "flowers": "flores", "flower": "flor", "grass": "grama", "tall": "alta", "wispy": "fina", "clover": "trevo", "fern": "samambaia",
	"mushroom": "cogumelo", "pebble": "pedrinha", "square": "quadrada", "petal": "pétala", "plant": "planta", "rock": "rocha", "rockpath": "pedras",
	"medium": "média", "anvil": "bigorna", "axe": "machado", "bronze": "", "bag": "saco", "banner": "estandarte", "cloth": "pano", "barrel": "barril",
	"apples": "maçãs", "holder": "suporte", "bed": "cama", "twin1": "", "twin2": "", "bench": "banco", "book": "livro", "books": "livros",
	"bookgroup": "livros", "bookstand": "estante de livro", "bookcase": "estante", "stack": "pilha", "bottle": "garrafa", "bucket": "balde",
	"metal": "metal", "wooden": "madeira", "cabinet": "armário", "cage": "gaiola", "candle": "vela", "candlestick": "castiçal", "stand": "suporte",
	"triple": "triplo", "carrot": "cenoura", "cauldron": "caldeirão", "chain": "corrente", "coil": "rolo", "chair": "cadeira", "chalice": "cálice",
	"chandelier": "lustre", "chest": "baú", "coin": "moeda", "pile": "monte", "dummy": "boneco", "farmcrate": "caixote", "apple": "maçã",
	"empty": "vazio", "key": "chave", "gold": "ouro", "lantern": "lanterna", "mug": "caneca", "nightstand": "criado-mudo", "shelf": "prateleira",
	"peg": "cabide", "rack": "", "pickaxe": "picareta", "pot": "pote", "lid": "tampa", "potion": "poção", "pouch": "bolsa", "large": "grande",
	"rope": "corda", "scroll": "pergaminho", "bottles": "garrafas", "smallbottle": "frasco", "smallbottles": "frascos", "stall": "barraca",
	"cart": "carrinho", "stool": "banquinho", "sword": "espada", "table": "mesa", "fork": "garfo", "knife": "faca", "plate": "prato",
	"spoon": "colher", "torch": "tocha", "vase": "vaso", "rubble": "caco", "weaponstand": "suporte de armas", "whetstone": "rebolo",
	"workbench": "bancada", "drawers": "gavetas", "shield": "escudo", "column": "coluna", "pedestal": "pedestal", "trap": "alçapão", "skull": "caveira",
	"cobweb": "teia", "statue": "estátua", "horse": "cavalo", "modular": "", "tile": "piso", "piles": "moedas", "mount": "suporte",
	"with": "com", "fantasy": "", "house": "casa", "inn": "estalagem", "blacksmith": "ferreiro", "stable": "estábulo", "mill": "moinho",
	"sawmill": "serraria", "barracks": "guarita", "bell": "sino", "well": "poço", "market": "mercado", "gazebo": "gazebo", "bonfire": "fogueira",
	"smoke": "fumaça", "hay": "feno", "package": "pacote", "path": "caminho", "saw": "serra", "sign": "placa", "lamp": "lampião", "pillar": "pilar",
	"bird": "pássaro", "pilory": "pelourinho", "fish": "peixe", "bread": "pão", "baguette": "baguete", "roll": "pãozinho", "pie": "torta",
	"cherry": "cereja", "croissant": "croissant", "cinnamon": "canela", "muffin": "bolinho", "cookie": "biscoito", "water": "água", "fountain": "fonte",
}

var categories: Array[String] = []
## categoria -> lista de entradas {key, nome, dica, grupo, varia, escala, estrutura, busca}
var entries: Dictionary[String, Array] = {}
var by_key: Dictionary[String, Dictionary] = {}
## Pacotes do acervo (para o filtro), na ordem.
var acervo_packs: Array[String] = []


func _init() -> void:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(PROPS):
		if file.ends_with(".tscn"):
			files.append(file.get_basename())
	for key: String in PIECES:
		if files.has(key):
			var p: Array = PIECES[key]
			_add(p[1], {"key": PROPS + key + ".tscn", "nome": p[0], "dica": p[5], "grupo": p[2], "varia": p[3], "escala": 1.0, "estrutura": p[4]})
	for key: String in files:
		if not PIECES.has(key):
			_add("Outras peças", {"key": PROPS + key + ".tscn", "nome": key.capitalize(), "dica": "", "grupo": "Props", "varia": false,
				"escala": 1.0, "estrutura": false})
	for dir: String in KITS:
		var info: Array = KITS[dir]
		var names: Array[String] = []
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gltf") or file.ends_with(".glb"):
				names.append(file)
		names.sort()
		for file: String in names:
			var base := file.get_basename()
			var structure: bool = info[3]
			var group: String = info[1]
			if dir.ends_with("natureza/") and base.begins_with("Rock"):
				group = "Rocks"
			_add(info[0], {"key": dir + file, "nome": pretty(base), "dica": base.replace("_", " "), "grupo": group,
				"varia": dir.ends_with("natureza/"), "escala": info[2], "estrutura": structure})
	_load_acervo()
	for c: String in ORDER:
		if entries.has(c):
			categories.append(c)
	for c: String in entries:
		if not categories.has(c):
			categories.append(c)


## O acervo entra numa categoria só, com o pacote de cada modelo (o editor filtra por pacote).
func _load_acervo() -> void:
	var path := ACERVO + "indice.json"
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array:
		return
	for item: Variant in data:
		var m := item as Dictionary
		var pack := String(m.get("pacote", ""))
		if not acervo_packs.has(pack):
			acervo_packs.append(pack)
		var terms: PackedStringArray = []
		for t: Variant in m.get("termos", []):
			terms.append(String(t))
		_add(ACERVO_CATEGORY, {"key": String(m["key"]), "nome": String(m["nome"]),
			"dica": "%s · %s (%s)%s" % [pack, m.get("autor", ""), m.get("licenca", ""), ("\n" + ", ".join(terms)) if not terms.is_empty() else ""],
			"grupo": "Props", "varia": false, "escala": 1.0, "estrutura": false, "pacote": pack, "acervo": true,
			"autor": String(m.get("autor", "")), "licenca": String(m.get("licenca", ""))})
	acervo_packs.sort()


func _add(category: String, entry: Dictionary) -> void:
	if not entries.has(category):
		entries[category] = []
	entry["categoria"] = category
	entry["busca"] = (String(entry["nome"]) + " " + String(entry["dica"]) + " " + String(entry["key"]).get_file() + " " + category).to_lower()
	entries[category].append(entry)
	by_key[String(entry["key"])] = entry


## "Wall_Plaster_Door_Round" -> "Parede reboco porta redonda". Número no fim vira "2", "3"...
static func pretty(base: String) -> String:
	var words: PackedStringArray = []
	for part: String in base.split("_"):
		var low := part.to_lower()
		if low.is_valid_int():
			words.append(part)
			continue
		var tail := ""
		while low.length() > 1 and low[-1].is_valid_int():
			tail = low[-1] + tail
			low = low.substr(0, low.length() - 1)
		var word: String = WORDS.get(low, part.replace("-", " ").to_lower())
		if word != "":
			words.append(word)
		if tail != "" and tail != "1":
			words.append(tail)
	var text := " ".join(words).strip_edges()
	return text.capitalize() if text == "" else text[0].to_upper() + text.substr(1)


## Ícone pronto da peça (gerado por tools/editor/gerar_icones.gd), ou null.
static func icon_path(key: String) -> String:
	if key.begins_with(ACERVO):
		return key.get_basename() + ".webp"  # a foto que o próprio poly.pizza mostra
	return ICONS + key.trim_prefix("res://").replace("/", "_").get_basename() + ".png"


func search(text: String) -> Array:
	var query := text.strip_edges().to_lower()
	var out: Array = []
	for c: String in categories:
		for e: Dictionary in entries[c]:
			if query == "" or String(e["busca"]).contains(query):
				out.append(e)
	return out
