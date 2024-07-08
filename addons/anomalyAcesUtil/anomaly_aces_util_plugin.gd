@tool
extends EditorPlugin


func _enter_tree():
	# Initialization of the plugin goes here.
	#Add Autoloads
	add_autoload_singleton("AceArrayUtil", "res://addons/anomalyAcesUtil/Scripts/AceArrayUtil.gd")
	pass


func _exit_tree():
	remove_autoload_singleton("AceArrayUtil")
