extends HBoxContainer

@onready var content_container: VBoxContainer = %ContentContainer

# This is a pixelorama class
var expand_container = load("res://src/UI/Nodes/CollapsibleContainer.gd")


func display(text: String):
	var parser_result = []

	var code_started = false
	var split_array := text.split("[/codeblock]", false)

	for section in split_array:
		var code_block: String
		var content: String
		if "[codeblock]" in section:
			var split = section.split("[codeblock]", false)
			if split.size() > 1:  # Failsafe
				code_block = split[1]
				section = split[0]
		for line in section.split("\n"):
			if "[h1]" in line or "[h2]" in line or "../../static/img/" in line:
				if not content.is_empty():
					parser_result.append(["content", content])
					content = ""
				if "[h1]" in line:
					parser_result.append(["h1", line.replace("[h1]", "")])
				elif "[h2]" in line:
					parser_result.append(["h2", line.replace("[h2]", "")])
				elif "/static/img/" in line:
					var main_ln = "https://raw.githubusercontent.com/Orama-Interactive/Pixelorama-Docs/refs/heads/master"
					var start = line.find("/static/img/")
					var img_link = line.substr(start, line.find(".png") + 4 - start)
					img_link = main_ln.path_join(img_link)

					parser_result.append(["image", img_link])
			else:
				content += "\n" + line
			content = content.strip_edges()


		if not content.is_empty():
			parser_result.append(["content", content])

		if not code_block.is_empty():
			parser_result.append(["codeblock", code_block])

	var tween = get_tree().create_tween()
	var delay = 0.5
	var visible_items = 2
	var content_parent = content_container
	var is_parent_collapsible = false
	for result in parser_result:
		if visible_items == 0:
			var collapse_container: VBoxContainer = expand_container.new()
			tween.tween_callback(content_parent.add_child.bind(collapse_container))
			content_parent = collapse_container
			collapse_container.text = "More"
			collapse_container.visible_content = true
			is_parent_collapsible = true
		visible_items -= 1
		match result[0]:
			"h1":
				var label = Label.new()
				label.theme_type_variation = &"HeaderSmall"
				var separator = HSeparator.new()
				tween.tween_callback(content_parent.add_child.bind(label))
				tween.tween_callback(content_parent.add_child.bind(separator))
				tween.tween_property(label, "text", result[1], delay)
			"h2":
				var label = Label.new()
				label.theme_type_variation = &"HeaderSmall"
				tween.tween_callback(content_parent.add_child.bind(label))
				tween.tween_property(label, "text", result[1], delay)
			"content":
				var label = RichTextLabel.new()
				label.bbcode_enabled = true
				label.selection_enabled = true
				label.fit_content = true
				tween.tween_callback(content_parent.add_child.bind(label))
				tween.tween_property(label, "text", result[1], delay)
			"codeblock":
				var label = preload("res://src/Extensions/QuickDocs/UI/codeblock.tscn").instantiate()
				tween.tween_callback(content_parent.add_child.bind(label))
				tween.tween_property(label, "text", result[1], delay)
			"image":
				var image = preload("res://src/Extensions/QuickDocs/UI/web_image.tscn").instantiate()
				tween.tween_callback(content_parent.add_child.bind(image))
				tween.tween_callback(image.display.bind(result[1]))
	if is_parent_collapsible:
		tween.tween_property(content_parent, "visible_content", false, 0.5)
