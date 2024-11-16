extends TextEdit


func _on_copy_pressed() -> void:
	var tween = get_tree().create_tween()
	DisplayServer.clipboard_set(text)
	$Copy/TextureRect.modulate = Color.GREEN
	tween.tween_property($Copy/TextureRect, "modulate", Color.WHITE, 1)
