extends VBoxContainer

const CRAWL_FILE = "res://src/Extensions/QuickDocs/crawl_data/doc_crawl_data.txt"
const request_preload = preload("res://src/Extensions/QuickDocs/UI/resquest.tscn")
const response_preload = preload("res://src/Extensions/QuickDocs/UI/response.tscn")

var word_data: Dictionary = {}
var para_data : Dictionary = {}

@onready var chat: VBoxContainer = $ScrollContainer/Chat

func _ready() -> void:
	var file = FileAccess.open(CRAWL_FILE, FileAccess.READ)
	var info: Array = str_to_var(file.get_as_text())
	file.close()
	word_data = info[0]
	para_data = info[1]


func _on_ask_pressed() -> void:
	var results: Dictionary
	var input: String = $HBoxContainer/TextEdit.text
	var your_message = request_preload.instantiate()
	chat.add_child(your_message)
	your_message.display(input)

	for keyword: String in input.split(" ", false):
		if keyword.length() > 3:
			for key: String in word_data.keys():
				if key.similarity(keyword) > 0.7:
					## get headers
					for section_header: String in word_data[key]:
						if section_header in results:
							results[section_header] = results[section_header] + 1
						else:
							results[section_header] = 1

	if not results.is_empty():
		var final_result = para_data[
			results.keys()[results.values().find(results.values().max())]
		]

		var answer = response_preload.instantiate()
		chat.add_child(answer)
		answer.display(md_to_bb(final_result))


func _on_clear_pressed() -> void:
	for child in chat.get_children():
		child.queue_free()


func md_to_bb(text: String) -> String:
	var result :String
	var caution_started := false
	var tip_started := false
	var danger_started := false
	var info_started := false

	var code_started := false

	var table_started := false

	for line in text.split("\n", false):
		### Tip highlights
		if line.begins_with(":::tip"):
			tip_started = true
			line = line.replace(":::tip", "[color=green]Tip: ")
		elif line.begins_with(":::caution"):
			caution_started = true
			line = line.replace(":::caution", "[color=orange]Caution: ")
		elif line.begins_with(":::info"):
			info_started = true
			line = line.replace(":::info", "[color=aqua]Info: ")
		elif line.begins_with(":::danger"):
			danger_started = true
			line = line.replace(":::danger", "[color=red]Danger: ")
		if line == ":::":
			if tip_started or caution_started or danger_started or info_started:
				line = line.replace(":::", "[/color]")
				match true:
					tip_started:
						tip_started = false
					caution_started:
						caution_started = false
					danger_started:
						danger_started = false
					info_started:
						info_started = false

		## Code detection
		if "`" in line:
			if "```" in line:
				if !code_started:
					code_started = true
					line = line.replace("```", "[color=dark_gray]")
				else:
					line = line.replace("```", "[/color]")
					code_started = false
			else:
				var formatted = ""
				for word in line.split(" ", false):
					if word.begins_with("`"):
						word = "[color=dark_gray]" + word.lstrip("`").replace("`", "[/color]")
					if word.ends_with("`"):
						word = word.rstrip("`") + "[/color]"
					formatted += " " + word + " "
				line = formatted.strip_edges()

		## headings
		if line.begins_with("## "):
			line = line.replace("## ", "\n[b][color=light_slate_gray]") + "[/color][/b]"
		if line.begins_with("### "):
			line = line.replace("### ", "\n[b]") + "[/b]"

		## url
		line = line.replace("<kbd>", "[b]")
		line = line.replace("</kbd>", "[/b]")

		## Tables
		if not "|" in line and table_started:
			line = "[/table]" + line
			table_started = false
		if "|" in line and not "---" in line:
			var cels = line.strip_edges().split("|", false)
			var is_heading := false
			if not table_started:
				table_started = true
				is_heading = true
				line = str("[table=", cels.size(), "]")
			for cel in cels:
				if is_heading:
					cel = str("[b]", cel, "[/b]")
				line += str("[cell]", cel, "[/cell]")

		## join them back together
		result = str(result, "\n", line)
	return result
