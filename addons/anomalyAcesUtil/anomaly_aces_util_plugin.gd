@tool
extends EditorPlugin


func _enter_tree():
	pass
	# Initialization of the plugin goes here.
	#Add Autoloads
	#add_autoload_singleton("AceArrayUtil", "res://addons/anomalyAcesUtil/Scripts/AceArrayUtil.gd")
	#pass


func _exit_tree():
	pass
	#remove_autoload_singleton("AceArrayUtil")
