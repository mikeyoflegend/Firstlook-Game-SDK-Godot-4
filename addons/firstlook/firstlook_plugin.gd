@tool
extends EditorPlugin

func _enable_plugin() -> void:
	add_autoload_singleton("FirstLook", "res://addons/firstlook/firstlook_sdk.gd")

func _disable_plugin() -> void:
	remove_autoload_singleton("FirstLook")
