@tool
extends Node

class_name TaskServerClient

## Works as an interface to use TaskServer from owner node.
##
## Proxy between TaskServerWorkItem issuer and TaskServer
##
## - Automatically finds running TaskServer and post work items to it
## - Provides signals for tracking work item status
## - Optionally can process work items locally in main thread


## Periodically sent when custom exucute function calls send_work_progress function
## Progress can be anything user deems it to be
signal work_progress(work_item, progress)

## Sent when work item is done, either by running all prepare, exucute and finalize steps or when its cancelled in any point.
signal work_ready(work_item)


var task_server


## Ignore TaskServer functionality and process work items in main thread
@export var process_locally = false

# Array of all owned work items for filtering incoming results from TaskServer
var work_items : Array = []


#func _ready():
#	pass


func post_work(work_item):
	#print("TaskServerClient dispatching work!")
	if process_locally:
		print(" - Processing locally: %s %s" % [work_item.ticket, work_item.metadata.name])
		work_item._work_prepare()
		work_item._work_execute()
		work_item._work_finalize()
		work_ready.emit(work_item)
		return
	
	work_items.push_back(work_item)
	if not task_server:
		_connect_to_taskserver()
	task_server.post_work(work_item)


func _connect_to_taskserver():
	# use earlier instance of task server if it can be found
	task_server = TaskServer
	if task_server:
		task_server.connect("work_progress", Callable(self, "_work_item_progress"))
		task_server.connect("work_ready", Callable(self, "_work_item_is_ready"))
		#print("Found running TaskServer[%s]!" % task_server.get_instance_id())
	else:
		push_error("Primary task server not found!")


# Connected to TaskServer
func _work_item_progress(work_item,progress):
	if work_items.has(work_item):
		#print("TaskServerClient found own item %s!" % work_item)
		emit_signal("work_progress",work_item,progress)


# Connected to TaskServer
func _work_item_is_ready(work_item):
	#print("TaskServerClient got ready item!")
	if work_items.has(work_item):
		#print("TaskServerClient found own item %s!" % work_item)
		emit_signal("work_ready",work_item)
		work_items.erase(work_item)

