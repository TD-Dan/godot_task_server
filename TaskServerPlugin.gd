@tool

extends EditorPlugin

var dock

var task_server


func _enter_tree():
	print("TaskServerPlugin loading...")
	name = "TaskServerPlugin"
	
	add_custom_type("TaskServerClient", "Node", preload("TaskServerClient.gd"), preload("icon_ts.png"))
	
	dock = preload("res://addons/godot_task_server/TaskServerDock.tscn").instantiate()
	#var dock_res = preload("res://addons/godot_task_server/TaskServerDock.tscn")
	#dock_res.resource_local_to_scene = true
	#dock = dock_res.instance()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	
	add_autoload_singleton("TaskServer", "res://addons/godot_task_server/TaskServer.gd")
	
	
	print("TaskServerPlugin load ready")
	
	call_deferred("_post_ready")


func _post_ready():
	task_server = get_node("/root/TaskServer")
	if task_server:
		print("TaskServerPlugin found primary TaskServer.")
	else:
		print("TaskServerPlugin can't find master TaskServer. Please add TaskServer.gd as Autoload!")
	


func _exit_tree():
	print("TaskServerPlugin unloading...")
	remove_custom_type("TaskServerClient")
	remove_control_from_docks(dock)
	remove_autoload_singleton("TaskServer")
	dock.free()

