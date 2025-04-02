@tool
extends EditorScript

## Path to the doc we intend to crawl
## NOTE: (I temporarily add pixelorama docs here, Then do File > Run then delete the folder)

const DOC_PATH = "res://docs/"
const OUTPUT_FILE = "res://src/Extensions/QuickDocs/crawl_data/doc_crawl_data.txt"

var word_data: Dictionary[String, Array] = {}
var para_data : Dictionary = {}

func _run() -> void:
	crawl(DOC_PATH)


func crawl(first_dir: String):
	print("Started")
	para_data.clear()
	word_data.clear()
	for path in get_paths_in_dir(first_dir, [".md"]):
		get_data(path)

	var file = FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	file.store_string(var_to_str([word_data, para_data]))
	file.close()
	print("Finished")


func get_data(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	var current_header = path.get_file()
	var header_count: int = 0
	var current_para = ""
	var last_line = ""
	while !file.eof_reached():
		var line = file.get_line()
		if line == "---":
			if last_line == "":
				while true and not file.eof_reached():
					line = file.get_line()
					if line.begins_with("---"):
						line = file.get_line()
						break
			else:
				line = str("## ", last_line)
				current_para = current_para.rstrip(last_line)
				current_para = current_para.strip_edges()
		if line.begins_with("## "):  # Next heading (store previous para)
			para_data[current_header] = current_para
			current_para = ""
			current_header = path.get_file().path_join(
				str(line.lstrip("## "), "(", header_count, ")")
			)
			header_count += 1

		## Parsing area
		if line.strip_edges() != "":
			last_line = line
			current_para = str(current_para, "\n", line)

		## generate word to header dictionary
		for word in line.capitalize().split(" ", false):
			var skip := false
			for forbidden in ["static/img", "http"]:
				if forbidden in word:
					skip = true
					break
			if skip: continue

			word = (word.strip_edges()
						.rstrip(".")
						.replace("&amp;", "")
						.replace("&", "")
						.replace("</kbd>", "")
						.replace("#", "")
						.replace("<kbd>", "")
						.replace("-", "")
						.replace(",", "")
						.replace("!", "")
						.replace("*", "")
						.replace("`", "")
						.replace(":", "")
						.replace("\"", "")
						.replace("[", "")
						.replace("]", "")
						.replace("(", "")
						.replace(")", "")
						.replace("{", "")
						.replace("}", "")
					)
			# Filter out any useless words (e.g the, an, etc...)
			if not word in ["a", "an", "or", "the", "but", "and", "so", ""]:
				if word_data.has(word):
					var word_references: Array = word_data[word]
					if not current_header in word_data[word]:
						word_references.append(current_header)
						word_data[word] = word_references
				else:
					word_data[word] = [current_header]
	para_data[current_header] = current_para


# It is a function that returns array of all paths inside a parent directory
func get_paths_in_dir(parent :String, filter: Array[String]) -> PackedStringArray:
	parent = parent.rstrip("/")
	var paths := PackedStringArray()
	var child_number = 0
	var main_parent_node :String = parent
	# Get children in the parent
	# The initial parent is the node we entered as "parent"
	var current_folder_files := list_files_in_directory(parent)
	var scanned_directories := PackedStringArray()
	while child_number < current_folder_files.size():
		var child_node = current_folder_files[child_number]
		# If the path is not yet registered then add it to "paths"
		if not child_node in paths and not child_node in scanned_directories:
			# If "child_node" has more further children then make child_node the new "parent"
			var test_directory = list_files_in_directory(child_node)
			if test_directory.size() != 0:
				parent = child_node
				current_folder_files = test_directory
				# And reset child_number (i set it to "-1" because later it will be added
				# By "child_number += 1" to make it "0"
				child_number = -1
			else:
				for word in filter:
					if word in child_node:
						paths.append(child_node)
						break
		child_number += 1
		## If children to children path secuence has ended then make the child's parent as
		## The next parent and move on to the next child
		if child_number == current_folder_files.size():
			scanned_directories.append(parent)
			# If all the paths are obtained then break the loop
			if parent == main_parent_node:
				return paths
			# else continue the sane with next node in line
			var dir := DirAccess.open(parent)
			dir.change_dir("..")
			parent = dir.get_current_dir()
			current_folder_files = list_files_in_directory(parent)
			child_number = 0
	return paths


func list_files_in_directory(path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var dir = DirAccess.open(path)
	if DirAccess.get_open_error() != OK:
		return []
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			paths.append(path.path_join(file))
	dir.list_dir_end()
	return paths
