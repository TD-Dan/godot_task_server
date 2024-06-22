@tool

extends Control

@onready var info_label = $Panel/VBoxContainer/InfoLabel
@onready var thread_info_label = $Panel/VBoxContainer/ThreadInfoLabel
@onready var event_info_container = $Panel/VBoxContainer/ScrollContainer/VBoxContainer2
@onready var event_info_label = $Panel/VBoxContainer/ScrollContainer/VBoxContainer2/EventInfoLabel

var autoload_task_server = null

func _ready():	
	info_label.text = "Connecting to TaskServer..."
	
	if not Engine.is_editor_hint():
		%SettingsButton.visible = false
	
	call_deferred("connect_to_taskserver")


func connect_to_taskserver():
	autoload_task_server = get_node_or_null("/root/TaskServer")
	
	if not autoload_task_server:
		push_warning("TaskServerDock can't find primary TaskServer. something wrong with setting TaskServer.gd as Autoload?")
		info_label.text = "Primary TaskServer not found"
		return
	else:
		print("TaskServerDock found primary TaskServer.")
	
	autoload_task_server.connect("work_ready", Callable(self, "_on_work_ready"))
	autoload_task_server.connect("status_report", Callable(self, "_on_status_report"))
	
	
	info_label.text = "TaskServer is active"
	thread_info_label.text = "Waiting for thread status.."
	
	%ThreadCountSpinBox.set_value_no_signal(autoload_task_server.num_threads)
	
	autoload_task_server.pull_status_report.call_deferred()


func _on_work_ready(work_item : TaskServerWorkItem):
	event_info_label = event_info_label.duplicate()
	event_info_container.add_child(event_info_label)
	event_info_container.move_child(event_info_label,0)
	var p = work_item.metadata.time_s_prepare
	var e = work_item.metadata.time_s_execute
	var f = work_item.metadata.time_s_finalize
	var status_text = "ready"
	if work_item.cancel:
		status_text = "cancelled"
	event_info_label.text = "%s: %s %s - P:%s E:%s F:%s T:%s" % [work_item.ticket, work_item.metadata.name, status_text, p, e, f, p+e+f]
	
	if event_info_container.get_child_count() >= 30:
		event_info_container.remove_child(event_info_container.get_child(29))


func _on_status_report(ticket_counter, work_queue_length, thread_count, threads_active):
	#print("updating thread status")
	thread_info_label.text = "Ticket nr: %s\nWork queue length: %s\nThread count: %s\nThreads busy: %s" % [ticket_counter, work_queue_length, thread_count, threads_active]


func _on_button_pressed():
	EditorInterface.edit_node(autoload_task_server)


func _on_thread_count_spin_box_value_changed(value):
	autoload_task_server.num_threads = value
	%ThreadCountSpinBox.set_value_no_signal(value)
