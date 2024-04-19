@tool

extends Control

@onready var info_label = $Panel/VBoxContainer/InfoLabel
@onready var thread_info_label = $Panel/VBoxContainer/ThreadInfoLabel
@onready var event_info_container = $Panel/VBoxContainer/ScrollContainer/VBoxContainer2
@onready var event_info_label = $Panel/VBoxContainer/ScrollContainer/VBoxContainer2/EventInfoLabel

var master_task_server = null
var editor_interface = null

func _ready():	
	info_label.text = "Connecting to TaskServer..."
	call_deferred("connect_to_taskserver")


func connect_to_taskserver():
	master_task_server = get_node("/root/TaskServer")
	
	if master_task_server:
		print("TaskServerDock found master TaskServer.")
	else:
		print("TaskServerDock can't find master TaskServer. Please add TaskServer.gd as Autoload!")
		info_label.text = "Master TaskServer not found"
		return
	
	master_task_server.connect("work_ready", Callable(self, "_on_work_ready"))
	master_task_server.connect("status_report", Callable(self, "_on_status_report"))
	
	editor_interface = get_node("/root/EditorNode/TaskServerPlugin").get_editor_interface()
	
	info_label.text = "TaskServer %s is active" % master_task_server.get_instance_id()
	thread_info_label.text = "Waiting for thread status.."
	
	master_task_server.pull_status_report()


func _on_Button_pressed():
	if editor_interface:
		editor_interface.inspect_object(master_task_server)


func _on_work_ready(work_item):
	event_info_label = event_info_label.duplicate()
	event_info_container.add_child(event_info_label)
	event_info_container.move_child(event_info_label,0)
	var p = work_item.metadata.time_s_prepare
	var e = work_item.metadata.time_s_execute
	var f = work_item.metadata.time_s_finalize
	event_info_label.text = "%s: %s ready: P:%s E:%s F:%s T:%s" % [work_item.ticket, work_item.metadata.name, p, e, f, p+e+f]
	
	if event_info_container.get_child_count() >= 30:
		event_info_container.remove_child(event_info_container.get_child(29))


func _on_status_report(ticket_counter, work_queue_length, thread_count, threads_active):
	thread_info_label.text = "Ticket nr: %s\nWork queue length: %s\nThread count: %s\nThreads busy: %s" % [ticket_counter, work_queue_length, thread_count, threads_active]
