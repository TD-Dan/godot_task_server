tool
extends Node

class_name TaskServerClient

# Works as a proxy between Task Issuer and TaskServer
#
# Automatically finds running TaskServer
# Only forwards signals for work items issued by TaskServerClient owner, ignoring other TaskServer signals
# Optionally can process work items locally in main thread

signal work_progress(work_item, progress)
signal work_ready(work_item)

var master_task_server

export var process_locally = false
var local_cache : Dictionary = {}

var work_items : Array = []

func _ready():
	pass


func get_master_taskserver():
	# use earlier instance of task server if it can be found
	master_task_server = get_node("/root/TaskServer")
	if master_task_server:
		master_task_server.connect("work_progress",self,"_work_item_progress")
		master_task_server.connect("work_ready",self,"_work_item_is_ready")
		#print("Found running TaskServer[%s]!" % master_task_server.get_instance_id())
	else:
		print("Master task server not loaded!")


func post_work(work_item):
	#print("TaskServerClient dispatching work!")
	if process_locally:
		print(" - Processing locally: %s %s" % [work_item.ticket, work_item.metadata.name])
		work_item._work_prepare()
		work_item._work_execute(local_cache)
		work_item._work_finalize()
		emit_signal("work_ready",work_item)
	else:
		work_items.push_back(work_item)
		if not master_task_server:
			get_master_taskserver()
		master_task_server.post_work(work_item)

func _work_item_progress(work_item,progress):
	if work_items.has(work_item):
		#print("TaskServerClient found own item %s!" % work_item)
		emit_signal("work_progress",work_item,progress)

func _work_item_is_ready(work_item):
	#print("TaskServerClient got ready item!")
	if work_items.has(work_item):
		#print("TaskServerClient found own item %s!" % work_item)
		emit_signal("work_ready",work_item)
		work_items.erase(work_item)
