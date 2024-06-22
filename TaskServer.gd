@tool

extends Node

## class_name TaskServer

## TaskServer
##
## Manages threads and schedules tasks for them
##


signal work_progress(work_item, progress)
signal work_ready(work_item)

signal status_report(ticket_counter, work_queue_length, thread_count, threads_active)


## Number of threads to use. 0 to use system max cores. Negative numbers to use (system max cores - number), f.ex. -2 = system max 16 cores - 2 = 14 threads.
@export var num_threads : int = -1:
	set(new_value):
		print("setting num threads from %s to %s" % [num_threads, new_value])
		num_threads = new_value
		var max_threads = OS.get_processor_count()
		print("MAX THREADS: %s" % max_threads)
		
		if num_threads < 0:
			num_threads = max_threads + num_threads
		if num_threads == 0 or num_threads > max_threads:
			num_threads = max_threads
		
		print("%s: requested %s threads; setting thread count to %s" % [self, new_value, num_threads])
		
		_close_threads()
		_start_threads(num_threads)


@export var thread_priority: Thread.Priority = Thread.PRIORITY_NORMAL:
	set(new_value):
		_close_threads()
		_start_threads(num_threads)


## Ensure that no tasks are left undone forever by increasing priorities over time.
## This amount is added to each unstarted WorkItem over one second to make them gradually more important
@export var task_priority_increase_per_second = 1.0


# Worker threads
var threadPool = []

# How many threads are working on a WorkItem
var threads_busy = 0
var threads_busy_mutex : Mutex = Mutex.new()


var semaphore = Semaphore.new()


# Used to signal all threads to stop themselves
var exit_threads : bool = false
var exit_threads_mutex : Mutex = Mutex.new()

var ticket_counter = 0

var work_queue = []
var mutex_work_queue : Mutex = Mutex.new()

var ready_queue = []
var mutex_ready_queue : Mutex = Mutex.new()

var taskserver_is_running = false


func _ready():
	start_up()


func _process(delta):
	mutex_work_queue.lock()
	for wi in work_queue:
		wi.priority += task_priority_increase_per_second * delta
	mutex_work_queue.unlock()
	
	mutex_ready_queue.lock()
	var ready_item = ready_queue.pop_front()
	mutex_ready_queue.unlock()
	
	if ready_item:
		call_deferred("finalize_and_return", ready_item)


func emit_status():
	mutex_work_queue.lock()
	var num_work_items = work_queue.size()
	mutex_work_queue.unlock()
	emit_signal("status_report", ticket_counter, num_work_items, threadPool.size(), threads_busy )


func pull_status_report():
	emit_status()

func send_work_progress(work_item, progress):
	emit_signal("work_progress",work_item, progress)

func finalize_and_return(work_item):
	work_item._work_finalize()
	emit_signal("work_ready",work_item)
	emit_status()


func start_up():
	if taskserver_is_running:
		push_warning("%s: already running. Stop server first before starting again." % self)
		return
	
	print("TaskServer[%s] starting up..." % get_instance_id())
	
	# Lauch threads
	num_threads = num_threads
	
	taskserver_is_running = true

# Get a new TaskServerWorkItem. Same as TaskeServerWorkItem.new(), but does not cause parser error if TaskServer plugin is not loaded
func create_work_item() ->  TaskServerWorkItem:
	var ret = TaskServerWorkItem.new()
	return ret


## Post TaskServerWorkItem to first worker thread available
func post_work(work_item : TaskServerWorkItem):
	#print("TaskServer received work!")
	if not taskserver_is_running:
		start_up()
	
	ticket_counter = ticket_counter + 1
	work_item.ticket = ticket_counter
	work_item._work_prepare()
	
	mutex_work_queue.lock()
	work_queue.push_back(work_item)
	mutex_work_queue.unlock()
	
	semaphore.post()
	
	return ticket_counter


# Starts specified number of threads
func _start_threads(count):
	print("Starting %s threads" % count)
	
	exit_threads_mutex.lock()
	exit_threads = false
	exit_threads_mutex.unlock()
	
	for i in range(count):
		var ntp_thread = Thread.new()
		ntp_thread.start(Callable(self, "_worker_thread").bind({"thread":ntp_thread}), thread_priority)
		threadPool.push_back(ntp_thread)
	
	emit_status()


# Closes all running threads.
func _close_threads():
	
	exit_threads_mutex.lock()
	exit_threads = true
	exit_threads_mutex.unlock()
	
	# Unblock by posting.
	for i in range(threadPool.size()):
		semaphore.post()
	
	# Block till all threads have finished
	for i in range(threadPool.size()):
		#print("Waiting for thread to finish...")
		threadPool[i].wait_to_finish()
	
	threadPool.clear()
	
	emit_status()


# Thread worker main loop
func _worker_thread(userdata):
	print("%s: Worker thread running." % userdata.thread.get_id())
	
	# Dictionary that can be accessed from all work item execute functions to store data for subsequent uses
	var thread_cache : Dictionary = {}
	
	while true:
		semaphore.wait() # Wait until work is posted.
		
		# If TaskServer is shutting down exit before work starts
		exit_threads_mutex.lock()
		var should_exit = exit_threads 
		exit_threads_mutex.unlock()
		if should_exit:
			break
		
		threads_busy_mutex.lock()
		threads_busy = threads_busy + 1
		threads_busy_mutex.unlock()
		
		mutex_work_queue.lock()
		# search for highest priority
		var work_item = work_queue[0]
		for wi in work_queue:
			if wi.priority > work_item.priority:
				work_item = wi
		work_queue.erase(work_item)
		mutex_work_queue.unlock()
		
		#signal start of work
		call_deferred("send_work_progress", work_item, 0)
		
		#print("%s: Worker thread working on: t:%s p:%s" % [userdata.thread.get_id(), work_item.ticket, work_item.priority])
		work_item._work_execute(thread_cache)
		
		mutex_ready_queue.lock()
		ready_queue.push_back(work_item)
		mutex_ready_queue.unlock()
		
		threads_busy_mutex.lock()
		threads_busy = threads_busy - 1
		threads_busy_mutex.unlock()
		
	print("%s: Worker thread exit" % userdata.thread.get_id())


func _exit_tree():
	print("TaskServer closing down...")
	_close_threads()
