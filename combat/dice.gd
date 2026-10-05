class_name Dice
extends RefCounted
## Dados de RPG. Gerador próprio para os testes poderem fixar a semente (Dice.rng.seed = 42).

static var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func roll(count: int, sides: int) -> int:
	var total := 0
	for i: int in count:
		total += rng.randi_range(1, sides)
	return total


static func d20() -> int:
	return rng.randi_range(1, 20)
