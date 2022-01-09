extends Reference #inherit Reference for automatic memory management, more lightweight than Node

class_name TaskServerWorkItem

class TaskItemMetaData:
	var name:String = "workitem"
	var time_s_prepare:float = 0
	var time_s_execute:float = 0
	var time_s_finalize:float = 0



var ticket : int
var priority : float = 10.0 setget _set_priority
var function : FuncRef
var data

var cancel = false

var metadata = TaskItemMetaData.new()


func _set_priority(nv):
	priority = max(nv, 0)


func _init(t : int = 0,f : FuncRef = null, d = null):
	ticket = t
	function = f
	data = d


# Called when work item is sheduled for execution
func _work_prepare():
	if not cancel:
		var time_start =  OS.get_ticks_msec()
		prepare()
		var time_end = OS.get_ticks_msec()
		metadata.time_s_prepare = (time_end - time_start) / 1000.0
#	else:
#		print(" - Preparation cancelled")

# Prepare data for execution before sending to worker thread
# This function is replaced on inherited classes
func prepare():
	pass

# Called when work item is executed
func _work_execute(_thread_cache : Dictionary):
	if not cancel:
		var time_start =  OS.get_ticks_msec()
		execute(_thread_cache)
		var time_end = OS.get_ticks_msec()
		metadata.time_s_execute = (time_end - time_start) / 1000.0
#	else:
#		print(" - Execute cancelled")

# Executed inside a thread
# cache is an array that can be used to store data in the worker threads memory
# This function can be replaced on inherited classes
func execute(_thread_cache : Dictionary):
	if function:
		if function.is_valid():
			print("TaskServer: Executing task with ticket %s" % ticket)
			data = function.call_func(data)
	else:
		print("   !!! Warning !!! Invalid function for work_item or execute function not defined in sub-class!")


# Called after work item has been executed
# Called inside main thread
func _work_finalize():
	if not cancel:
		var time_start =  OS.get_ticks_msec()
		finalize()
		var time_end = OS.get_ticks_msec()
		metadata.time_s_finalize = (time_end - time_start) / 1000.0
#	else:
#		print(" - Finalize cancelled")

# called after execution when work_item has been returned to sender
# This function is replaced on inherited classes
func finalize():
	pass
