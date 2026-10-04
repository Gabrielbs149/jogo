extends GutTest
## Prova que o GUT roda no CI. Pode apagar quando existir teste de verdade.


func test_gut_is_running() -> void:
	assert_eq(2 + 2, 4)
