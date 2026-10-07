# Jogo (codinome)

Jogo do Gabriel e do John, feito em **Godot 4.7.2** + GDScript: RPG 3D baseado na campanha **A Noite Sem Nome** do grupo. Você escolhe um dos cinco heróis, explora em 3ª pessoa e luta por turnos com QTE (estilo Clair Obscur, regras de D&D 5.5). Design completo em [docs/gdd/](docs/gdd/00-visao-geral.md).

## Controles
**Explorando**
| | |
|---|---|
| Andar / correr | WASD ou setas / Shift |
| Câmera | mouse (Esc solta) |
| Interagir (ler, conversar, descansar, viajar, chamar herói) | F |
| Primeiro golpe num grupo de inimigos | botão esquerdo |
| Editor de mapas | F2 |

**Lutando** (arena por turnos; começa ao encostar num grupo)
| | |
|---|---|
| Atacar (+1 PA) | 1 ou Enter |
| Habilidades (custam PA) | Q / E / R |
| Trocar alvo | A / D |
| Acertar o tempo do golpe | Espaço quando o anel fecha |
| Esquivar / aparar | Espaço / F (ou botão direito) |

**Cenas:** Espaço, F ou clique passam; Esc pula.

## Primeira vez
Siga o [docs/SETUP.md](docs/SETUP.md) (≈ 30 min).

## Dia a dia
1. **Começou:** sync. Duplo clique no `sync.cmd`, ou peça pro Claude: *"sincroniza"*.
2. **Fez algo que funciona:** sync de novo, com mensagem. A cada 30–60 min, não só no fim do dia.
3. **O Godot perguntou se quer recarregar arquivos?** Sempre **Reload**.
4. **Teve ideia:** *"anota essa ideia: ..."* para o Claude, ou uma issue com o template **Ideia**.

## Onde fica o quê
| | |
|---|---|
| Regras para os Claudes (e para a gente) | [CLAUDE.md](CLAUDE.md) |
| Design do jogo (fonte da verdade) | [docs/gdd/](docs/gdd/00-visao-geral.md) |
| História da campanha no jogo | [docs/gdd/01-historia.md](docs/gdd/01-historia.md) |
| Arte (estilo, assets) | [docs/gdd/04-arte.md](docs/gdd/04-arte.md) |
| Como usamos o Git | [docs/FLUXO.md](docs/FLUXO.md) |
| Fases e tarefas | [docs/gdd/07-roadmap.md](docs/gdd/07-roadmap.md) + board no GitHub Projects |
| Decisões tomadas | [docs/gdd/decisoes.md](docs/gdd/decisoes.md) |
| Ideias | Issues com label `ideia` |

## Equipe
| Quem | GitHub |
|---|---|
| Gabriel | @Gabrielbs149 |
| John | @JohnG-404 |
