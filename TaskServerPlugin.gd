tool

extends EditorPlugin

var dock

var master_task_server


func _enter_tree():
	print("TaskServer plugin loading...")
	name = "TaskServerPlugin"
	
	var dock_res = preload("res://addons/task_server/TaskServerDock.tscn")
	dock_res.resource_local_to_scene = true
	dock = dock_res.instance()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

	add_autoload_singleton("TaskServer", "res://addons/task_server/TaskServer.gd")
	
	#print(get_path())


func _ready():
	call_deferred("connect_to_taskserver")


func connect_to_taskserver():
	master_task_server = get_node("/root/TaskServer")
	if master_task_server:
		print("TaskServerPlugin found master TaskServer.")
	else:
		print("TaskServerPlugin can't find master TaskServer. Please add TaskServer.gd as Autoload!")


func _exit_tree():
	print("TaskServer plugin unloading...")
	remove_control_from_docks(dock)
	remove_autoload_singleton("TaskServer")
	dock.free()

