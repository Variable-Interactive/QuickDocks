extends VBoxContainer

const CRAWL_FILE = "res://src/Extensions/QuickDocs/crawl_data/doc_crawl_data.txt"
const request_preload = preload("res://src/Extensions/QuickDocs/UI/request.tscn")
const response_preload = preload("res://src/Extensions/QuickDocs/UI/response.tscn")

var word_data: Dictionary[String, Array] = {}
var para_data : Dictionary = {}

var added_chat_titles = []

@onready var chat: VBoxContainer = $ScrollContainer/Chat


func _ready() -> void:
	var file = FileAccess.open(CRAWL_FILE, FileAccess.READ)
	var info: Array = str_to_var(file.get_as_text())
	file.close()
	word_data = info[0]
	para_data = info[1]


func _on_ask_pressed() -> void:
	var results: Dictionary
	# Get the input text (and also put it out for display)
	var input: String = $HBoxContainer/TextEdit.text
	var your_message = request_preload.instantiate()
	chat.add_child(your_message)
	your_message.display(input)

	var resemble_threshold = 0.7  ## sections in docs having resembling words will be detected
	while results.is_empty():
		## Loop through all the bigger words in our input text
		for keyword: String in input.split(" ", false):
			if keyword.length() > 2:  # Ignore smaller words
				for key: String in word_data.keys():  # Search word base
					var score := key.to_lower().similarity(keyword.to_lower())
					if score > resemble_threshold:
						# Store all headers that contain the resembling word in their content
						for section_header: String in word_data[key]:
							# Track frequent occurances
							if not section_header in added_chat_titles:
								if section_header in results:
									results[section_header] = results[section_header] + score
								else:
									results[section_header] = score
		# If nothing resembling was found with the current resemble_threshold setting then
		# decrease it a bit and try again
		resemble_threshold -= 0.001
		if resemble_threshold < 0.3:  # Give up if nothing was found, even at the lowest value
			break

	# sort result on score and get top 5 best
	var result_headers = results.keys()
	result_headers.sort_custom(
		func (a, b): if results[a] > results[b]: return true else: return false
	)
	if result_headers.size() > 5:
		result_headers.resize(5)

	var answer = response_preload.instantiate()
	chat.add_child(answer)
	if not results.is_empty():
		# Pick the result with the largest amount of resembling keywords
		var final_result = para_data[result_headers[0]]
		added_chat_titles.append(para_data.keys()[para_data.values().find(final_result)])
		answer.display(md_to_bb(final_result))
	else:
		answer.display(
			"""
Sorry but it seems i couldn't find what you were looking for. Try a different keyword.
It is also possible that there are no more searches for this keyword.
Try clearing the chat.
			"""
		)


func _on_clear_pressed() -> void:
	added_chat_titles.clear()
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
	var ul_index_array := []

	for line in text.split("\n", false):
		var can_add_to_list = true  # No further action check
		### Tip highlights
		if line.begins_with(":::tip"):
			tip_started = true
			line = line.replace(":::tip", "[color=green]Tip: ")
			can_add_to_list = false
		elif line.begins_with(":::caution"):
			caution_started = true
			line = line.replace(":::caution", "[color=orange]Caution: ")
			can_add_to_list = false
		elif line.begins_with(":::info"):
			info_started = true
			line = line.replace(":::info", "[color=aqua]Info: ")
			can_add_to_list = false
		elif line.begins_with(":::danger"):
			danger_started = true
			line = line.replace(":::danger", "[color=red]Danger: ")
			can_add_to_list = false
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

		if "**" in line:
			line = replace_alternating(line, "**", "[b]", "[/b]")

		## bold text
		line = line.replace("<kbd>", "[b]")
		line = line.replace("</kbd>", "[/b]")

		## headings
		if line.begins_with("## "):
			line = line.replace("## ", "\n[h1]")
			can_add_to_list = false
		elif line.begins_with("### "):
			line = line.replace("### ", "\n[h2]")
			can_add_to_list = false
		elif line.begins_with("##### "):
			line = line.replace("##### ", "[center]") + "[/center]"
			can_add_to_list = false

		line = simplify_links(line)

		## Code detection
		if "`" in line:
			if "```" in line:
				if !code_started:
					code_started = true
					can_add_to_list = false
					line = line.replace("```", "[codeblock]")
				else:
					line = line.replace("```", "[/codeblock]")
					code_started = false
			else:
				line = replace_alternating(line, "`", "[color=yellow]", "[/color]")

		## Lists
		if line.strip_edges().begins_with("- "):  # unordered lists
			var index = line.find("-")
			line = line.erase(index, 2)
			line = line.strip_edges()
			if !index in ul_index_array:  # if a next list has started
				line = "[ul]" + line
				ul_index_array.append(index)
			else:
				if ul_index_array.size() != 0:
					if index < ul_index_array.max():  # a list is done
						line = "[/ul]" + line
						ul_index_array.erase(ul_index_array.max())
		elif ul_index_array.size() > 0:
			if not "|" in line and can_add_to_list:
				result = str(result, " ", line.strip_edges())
				continue
			if not can_add_to_list:
				var ending: String = ""
				for i in ul_index_array.size():
					ending += "[/ul]"
				ul_index_array.clear()
				result += ending

		## Tables
		if not "|" in line and table_started:
			line = "[/table][/center]\n" + line
			table_started = false
		if "|" in line and not "---" in line:
			var cels := line.strip_edges().split("|", false)
			var table_size = (cels.size() * 2) + 1
			var separator = ""
			for _i in table_size:
				separator += "[cell]-[/cell]"
			var is_heading := false
			var new_line = ""
			if not table_started:
				table_started = true
				is_heading = true
				new_line = str("\n[center][table=", table_size, "]")
				new_line += separator
			new_line += "[cell]|[/cell]"
			for cel: String in cels:
				cel = cel.strip_edges()
				if is_heading:
					cel = str("[b][u]", cel, "[/u][/b]")
				new_line += str("[cell]", cel, "[/cell]")
				new_line += "[cell]|[/cell]"
			new_line += separator
			line = new_line

		## join them back together
		result = str(result, "\n", line)
	return result


func replace_alternating(text: String, indicator: String, first: String, second: String) -> String:
	var start = text.find(indicator)
	while start != -1:
		text = text.erase(start, indicator.length()).insert(start, first)
		var ending_indicator = text.find(indicator)
		text = text.erase(ending_indicator, indicator.length()).insert(ending_indicator, second)
		start = text.find(indicator, start + 1)
	return text


func simplify_links(text: String) -> String:
	var separator = text.find("](")
	while separator != -1:
		var start = text.rfind("[", separator)
		var end = text.find(")", separator)
		var label = text.substr(start + 1, separator - start - 1)
		var url = text.substr(separator + 2, end - separator - 2)
		if not "static/img/" in url:
			text = text.erase(start, (end - start) + 1).insert(start, label)
			separator = text.find("](")
		else:
			separator = text.find("](", separator + 1)
	return text
