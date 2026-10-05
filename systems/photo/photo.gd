class_name PhotoCamera
extends CanvasLayer
## A câmera do jogador (autoload "Photo"). Cada foto gasta filme, dá um flash, mostra a cena
## em negativo e revela os Revealable. A imagem vai para o álbum, com a legenda do que apareceu nela.

signal photo_taken(index: int, captions: PackedStringArray)

@export var film_capacity: int = 12
## Clarão mais fraco (opção de acessibilidade para fotossensibilidade).
@export var soft_flash: bool = false
## Quanto tempo o negativo fica na tela antes de se desfazer (segundos).
@export var negative_hold: float = 0.85
@export var negative_dissolve: float = 0.8

var film: int = 12
## Cada foto: {"texture": Texture2D (pode ser null), "captions": PackedStringArray}
var photos: Array[Dictionary] = []

var _shooting: bool = false
var _album_open: bool = false
var _album_index: int = 0
var _counter_tween: Tween

@onready var _counter: Control = %Counter
@onready var _counter_label: Label = %CounterLabel
@onready var _album: Control = %Album
@onready var _album_photo: TextureRect = %AlbumPhoto
@onready var _album_title: Label = %AlbumTitle
@onready var _album_caption: Label = %AlbumCaption


func _ready() -> void:
	film = film_capacity
	_counter.modulate.a = 0.0
	_album.hide()


func is_busy() -> bool:
	return _shooting or _album_open


func is_shooting() -> bool:
	return _shooting


func take() -> void:
	if _shooting:
		return
	if film <= 0:
		Dialogue.start("", PackedStringArray(["Acabou o filme."]))
		return
	_shooting = true
	film -= 1
	Dialogue.hide_prompt()

	Screen.flash = 0.5 if soft_flash else 1.0
	await get_tree().create_timer(0.07).timeout
	get_tree().call_group("revealable", "set_revealed", true)
	Screen.flash = 0.0
	Screen.negative = 1.0

	# Espera o negativo ser desenhado e guarda a imagem.
	# (process_frame, e não frame_post_draw: este último não dispara sem janela, como no CI)
	await get_tree().process_frame
	await get_tree().process_frame
	var captions := _captions_on_screen()
	photos.append({"texture": _grab_screen(), "captions": captions})
	photo_taken.emit(photos.size() - 1, captions)
	_show_counter()

	await get_tree().create_timer(negative_hold).timeout
	await create_tween().tween_property(Screen, "negative", 0.0, negative_dissolve).finished
	get_tree().call_group("revealable", "set_revealed", false)
	_shooting = false


func open_album() -> void:
	if _album_open:
		return
	_album_open = true
	Dialogue.hide_prompt()
	_album_index = maxi(photos.size() - 1, 0)
	_refresh_album()
	_album.show()


func close_album() -> void:
	_album_open = false
	_album.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _album_open:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("album") or event.is_action_pressed("ui_cancel"):
		close_album()
	elif event.is_action_pressed("move_left") and _album_index > 0:
		_album_index -= 1
		_refresh_album()
	elif event.is_action_pressed("move_right") and _album_index < photos.size() - 1:
		_album_index += 1
		_refresh_album()


func _refresh_album() -> void:
	if photos.is_empty():
		_album_photo.texture = null
		_album_title.text = "ÁLBUM   vazio"
		_album_caption.text = "Nenhuma foto ainda. F fotografa."
		return
	var photo: Dictionary = photos[_album_index]
	_album_photo.texture = photo["texture"]
	_album_title.text = "ÁLBUM   %d/%d   filme %d" % [_album_index + 1, photos.size(), film]
	var captions: PackedStringArray = photo["captions"]
	_album_caption.text = "\n".join(captions) if not captions.is_empty() else "Nada de estranho. Será?"


func _captions_on_screen() -> PackedStringArray:
	var found: PackedStringArray = []
	for node: Node in get_tree().get_nodes_in_group("revealable"):
		var revealable := node as Revealable
		if revealable and revealable.is_on_screen() and revealable.caption != "":
			found.append(revealable.caption)
	return found


func _grab_screen() -> Texture2D:
	# Sem janela (testes/CI) não existe imagem de tela para copiar
	if DisplayServer.get_name() == "headless":
		return null
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _show_counter() -> void:
	_counter_label.text = "FILME %d" % film
	if _counter_tween:
		_counter_tween.kill()
	_counter_tween = create_tween()
	_counter_tween.tween_property(_counter, "modulate:a", 1.0, 0.15)
	_counter_tween.tween_interval(2.0)
	_counter_tween.tween_property(_counter, "modulate:a", 0.0, 0.5)
