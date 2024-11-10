extends Node

var api: Node

# some references to nodes that will be created later
var panel

# This script acts as a setup for the extension
func _enter_tree() -> void:
	## NOTE: use get_node_or_null("/root/ExtensionsApi") to access api.
	api = get_node_or_null("/root/ExtensionsApi")
	# add a test panel as a tab  (this is an example) the tab is located at the same
	# place as the (Tools tab) by default
	panel = preload("res://src/Extensions/QuickDocs/UI/ChatPannel.tscn").instantiate()
	api.panel.add_node_as_tab(panel)


func _exit_tree() -> void:  # Extension is being uninstalled or disabled
	# remember to remove things that you added using this extension
	api.panel.remove_node_from_tab(panel)
