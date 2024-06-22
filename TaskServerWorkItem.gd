extends RefCounted #inherit RefCounted for automatic memory management, more lightweight than Node

class_name TaskServerWorkItem

## Performance tracking of WorkItems
class TaskItemMetaData:
	var name:String = "workitem"
	var time_s_prepare:float = 0
	var time_s_execute:float = 0
	var time_s_finalize:float = 0


## Unique ascending number assigned to this work item, 
var ticket : int


## How important is this work item. Larger number means more priority. Unit is seconds.
## F.ex. priority 1.0 means this task should take priority over any task issued with priority 0.0 during the next second.
## Priority -1.0 would mean that this task yields for default priority 0.0 tasks for 1 second.
## Default 0.0 priority tries to compute as fast as possible if no more important tasks are present.
var priority : float = 0.0


## Worker function to call upon execution
var function : Callable

## Data to provide for worker function for execution
var data

## Issue cancellation of the work item as soon as possible, worker function should periodically monitor this variable and return if set to true
var cancel = false:
	set(nv):
		cancel_mutex.lock()
		cancel = nv
		cancel_mutex.unlock()
	get:
		cancel_mutex.lock()
		var cl = cancel
		cancel_mutex.unlock()
		return cl
var cancel_mutex = Mutex.new()


# statistics for monitoring the task
var metadata = TaskItemMetaData.new()


func _init(t : int = 0,f = null, d = null):
	ticket = t
	if function:
		function = f
	data = d


# Called when work item is sheduled for execution
func _work_prepare():
	if cancel: return
	
	var time_start =  Time.get_ticks_msec()
	prepare()
	var time_end = Time.get_ticks_msec()
	metadata.time_s_prepare = (time_end - time_start) / 1000.0



## Prepare data for execution before sending to worker thread
## This function can be replaced in inherited classes
func prepare():
	pass


# Called when work item is executed
func _work_execute(_thread_cache : Dictionary):
	if cancel: return
	
	var time_start =  Time.get_ticks_msec()
	execute(_thread_cache)
	var time_end = Time.get_ticks_msec()
	metadata.time_s_execute = (time_end - time_start) / 1000.0
#	else:
#		print(" - Execute cancelled")


## Executed inside a thread
## cache is an array that can be used to store data in the worker threads memory
## This function can be replaced in inherited classes
func execute(_thread_cache : Dictionary):
	if function:
		if function.is_valid():
			print("TaskServer: Executing task with ticket %s" % ticket)
			if data:
				data = function.call(data)
			else:
				function.call()
	else:
		print("   !!! Warning !!! Invalid function for work_item or execute function not defined in sub-class!")


# Called after work item has been executed
# Called inside main thread
func _work_finalize():
	if cancel: return
		
	var time_start =  Time.get_ticks_msec()
	finalize()
	var time_end = Time.get_ticks_msec()
	metadata.time_s_finalize = (time_end - time_start) / 1000.0


## called after execution when work_item has been returned to sender
## This function can be replaced in inherited classes
func finalize():
	pass
