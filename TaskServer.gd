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

## Number of threads to use
@export var num_threads = 4:
	set(new_value):
		num_threads = new_value
		_close_threads()
		_start_threads(num_threads)


@export var thread_priority: Thread.Priority = Thread.PRIORITY_NORMAL:
	set(new_value):
		_close_threads()
		_start_threads(num_threads)


@export var priority_decay = 0.01:
	set(nv):
		priority_decay = clamp(nv, 0.0, 1.0)


var threadPool = []


var threads_busy = 0
var mutex_threads_busy


var mutex
var semaphore
var exit_thread

var ticket_counter = 0

var work_queue = []
var mutex_work_queue

var ready_queue = []
var mutex_ready_queue

var taskserver_is_running = false


func _ready():
	start_up()


func _process(delta):
	for wi in work_queue:
		wi.priority -= wi.priority * priority_decay * delta
	
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
		return
	
	print("TaskServer[%s] starting up..." % get_instance_id())
	# Find how many threads are supported
	
	# Launch worker threads
	mutex = Mutex.new()
	mutex_work_queue = Mutex.new()
	mutex_ready_queue = Mutex.new()
	mutex_threads_busy = Mutex.new()
	semaphore = Semaphore.new()
	exit_thread = false
	
	_start_threads(num_threads)
	
	taskserver_is_running = true


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
	
	mutex.lock()
	exit_thread = false
	mutex.unlock()
	
	for i in range(count):
		var ntp_thread = Thread.new()
		ntp_thread.start(Callable(self, "_worker_thread").bind({"thread":ntp_thread}), thread_priority)
		threadPool.push_back(ntp_thread)
	
	emit_status()


# Closes all running threads.
func _close_threads():
	
	mutex.lock()
	exit_thread = true
	mutex.unlock()
	
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
		
		#if shutting down exit before work starts
		mutex.lock()
		var should_exit = exit_thread # Protect with Mutex.
		mutex.unlock()
		if should_exit:
			break
		
		mutex_threads_busy.lock()
		threads_busy = threads_busy + 1
		mutex_threads_busy.unlock()
		
		mutex_work_queue.lock()
		# search for lowest priority
		var work_item = work_queue[0]
		for wi in work_queue:
			if wi.priority < work_item.priority:
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
		
		mutex_threads_busy.lock()
		threads_busy = threads_busy - 1
		mutex_threads_busy.unlock()
		
	print("%s: Worker thread exit" % userdata.thread.get_id())


func _exit_tree():
	print("TaskServer closing down...")
	_close_threads()
