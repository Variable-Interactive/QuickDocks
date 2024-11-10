extends HBoxContainer


func display(text: String):
	$RichTextLabel.text = text
	var tween = get_tree().create_tween()
	tween.tween_property($RichTextLabel, "visible_ratio", 1, 5)
