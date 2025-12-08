extends Control

### Global variables ###
var url : String # Room URL
var tracker_id : String # Tracker suuid

enum Request {ROOM, TOTALS, PROGRESS}
var request_type : int = Request.ROOM

var slot_data : Dictionary # Slot info (player, game, progress)
var slot_index : int = 0 # Used for progressing through slots for data
var chosen_slot_index : int = 0 # Used for progressing through slots for display

enum Display_Mode {PLAYER, GAME, BOTH} # Whether to show players, games or both
var display_mode : int = 0 # TODO - Actually give the option to show both...

var check_display : String # How checks are displayed as a string (% vs fraction)

### Node variables ###

## Helpers ##
@export var http_request : HTTPRequest
@export var timer : Timer # Used for spacing HTTPRequests and transitions

## Launch Menu ##

# Options/Configures
@export var display_selection : MenuButton # Lets the user choose how to display slot names
@export var url_lineedit : LineEdit # User types the end of the tracker url here

@export var color_picker_1 : ColorPickerButton
@export var color_picker_2 : ColorPickerButton
@export var color_reset_button : Button

@export var percentage_toggle : CheckBox
@export var completed_toggle : CheckBox

# Big awesome button
@export var launch_button : Button # Launches the progress window


## Progress Window ##
@export var progress_window : Window # Second window that displays the progress bar
@export var display_parent_a : Control # Parent for the two progress displays
@export var display_parent_b : Control
@export var display_text_a : RichTextLabel # Text for the two progress displays
@export var display_text_b : RichTextLabel
@export var progress_bar_a : ColorRect # Progress bar for the two progress displays
@export var progress_bar_b : ColorRect
@export var display_error : ColorRect # Error message

## Window Title Easter Egg ##
@export var title_eggs : Array[String]

# Initialize the scene
func _ready() -> void:
	# Set main window title
	get_window().title = "PPLauncher | %s" % title_eggs.pick_random()
	# Initialize text
	initialize_text()
	
	# Initialize subwindow transparency
	display_parent_a.modulate.a = 0
	
	hide_tracker()
	
	http_request.request_completed.connect(http_request_completed)
	
	display_selection.get_popup().id_pressed.connect(select_slot_option)

func select_slot_option(id : int) -> void:
	display_mode = id
	for i in range(0,display_selection.get_popup().item_count):
		display_selection.get_popup().set_item_checked(i, false)
	display_selection.get_popup().set_item_checked(id, true)

func initialize_text():
	display_text_a.text = "[center][wave]Loading[/wave][/center]"
	display_text_b.text = "[center][wave]Loading[/wave][/center]"
	
	progress_bar_b.position.x = -1000
	progress_bar_a.position.x = -1000

func _on_launch_button_pressed() -> void:
	reset_data()
	initialize_text()
	
	disable_buttons()
	
	# Set URL
	url = url_lineedit.text
	
	request_room()
	
	timer.start()

func request_room():
	show_tracker()
	if url.contains("/room/"):
		http_request.request(url.split("/room/")[0] + "/api/room_status/" + url.split("/room/")[1])
		display_error.visible = false
	else:
		display_error.visible = true

func http_request_completed(_result, _response_code, _headers, _body):
	if _response_code == 200:
		var parse_result = JSON.parse_string(_body.get_string_from_utf8())
		if parse_result is Dictionary:
			match request_type:
				Request.ROOM:
					set_slot_data(parse_result)
				Request.TOTALS:
					set_total_data(parse_result)
				Request.PROGRESS:
					set_progress_data(parse_result)
		else:
			display_error.visible = true
	else:
		display_error.visible = true

func set_slot_data(room_data):
	for player in room_data["players"]:
		slot_data[slot_index] = {
			"player": player[0],
			"game": player[1],
			"progress": "",
			"total": ""
		}
		slot_index += 1
	
	slot_data[slot_index] = {
		"player": "Total Checks",
		"game": "Total Checks",
		"progress": "",
		"total": ""
	}
	
	slot_index = 0
	request_type = Request.TOTALS
	tracker_id = room_data["tracker"]
	http_request.request(url.split("/room/")[0] + "/api/static_tracker/" + tracker_id)

func set_total_data(total_data):
	var total = 0
	for player in total_data["player_locations_total"]:
		slot_data[slot_index]["total"] = player["total_locations"]
		
		total += int(player["total_locations"])
		slot_index += 1
	
	slot_data[slot_index]["total"] = str(total)
	
	slot_index = 0
	request_type = Request.PROGRESS
	http_request.request(url.split("/room/")[0] + "/api/tracker/" + tracker_id)

func set_progress_data(progress_data):
	for player in progress_data["player_checks_done"]:
		if slot_data.keys().has(slot_index):
			slot_data[slot_index]["progress"] = player["locations"].size()
			# Mark completed games as such
			if int(slot_data[slot_index]["progress"]) == int(slot_data[slot_index]["total"]):
				slot_data[slot_index]["completed"] = true
			else:
				slot_data[slot_index]["completed"] = false
		slot_index += 1
	
	slot_data[slot_index]["progress"] = progress_data["total_checks_done"][0]["checks_done"]
	slot_data[slot_index]["completed"] = false
	
	var completed_slots = []
	
	if completed_toggle.button_pressed:
		for slot in slot_data:
			if slot_data[slot]["completed"]:
				completed_slots.append(slot)
	
		for slot in completed_slots:
			slot_data.erase(slot)
	
	populate_text()
	slot_index = 0

func reset_data():
	hide_tracker()
	timer.stop()
	slot_index = 0
	chosen_slot_index = 0
	slot_data.clear()
	request_type = Request.ROOM

func _on_single_game_window_close_requested() -> void:
	reset_data()
	enable_buttons()

func populate_text():
	start_transition()
	
	# Choose a slot to display
	var chosen_slot = slot_data.keys()[chosen_slot_index % slot_data.keys().size()]
	
	# Checks as fraction
	var check_fraction = "%s/%s" % [str(slot_data[chosen_slot]["progress"]).replace(".0",""), str(slot_data[chosen_slot]["total"]).replace(".0","")]
	# Checks as percentage
	var check_percentage = float(slot_data[chosen_slot]["progress"])/float(slot_data[chosen_slot]["total"])
	# Chosen check display
	if percentage_toggle.button_pressed:
		check_display = "%0.2f%%" % (check_percentage*100)
	else:
		check_display = check_fraction
	
	
	if chosen_slot_index % 2 == 0:
		## NODE 1
		set_text(display_text_a, chosen_slot, check_display)
		progress_bar_a.position.x = check_percentage * 1000 - 1000+40
	else:
		## NODE 2
		set_text(display_text_b, chosen_slot, check_display)
		progress_bar_b.position.x = check_percentage * 1000 - 1000+40
	
	# Move to the next slot
	chosen_slot_index += 1

func set_text(text_label : RichTextLabel, _slot : int, _checks : String):
	match display_mode:
		Display_Mode.PLAYER:
			text_label.text = "[center]%s: %s[/center]" % [slot_data[_slot]["player"], _checks]
		Display_Mode.GAME:
			text_label.text = "[center]%s: %s[/center]" % [slot_data[_slot]["game"], _checks]

func _on_timer_timeout() -> void:
	http_request.request(url.split("/room/")[0] + "/api/tracker/" + tracker_id)
	await http_request.request_completed
	timer.start(10)
	
func start_transition():
	var tween = get_tree().create_tween()
	var tween2 = get_tree().create_tween()
	if display_parent_a.modulate.a == 0:
		tween.tween_property(display_parent_b, "modulate", Color(0,0,0,0), 2)
		tween2.tween_property(display_parent_a, "modulate", Color(1,1,1,1), 2)
	else:
		tween.tween_property(display_parent_a, "modulate", Color(0,0,0,0), 2)
		tween2.tween_property(display_parent_b, "modulate", Color(1,1,1,1), 2)

func disable_buttons() -> void:
	display_selection.disabled = true
	launch_button.disabled = true
	url_lineedit.editable = false
	
	color_picker_1.disabled = true
	color_picker_2.disabled = true
	color_reset_button.disabled = true
	
	percentage_toggle.disabled = true
	completed_toggle.disabled = true
	
func enable_buttons() -> void:
	launch_button.disabled = false
	display_selection.disabled = false
	url_lineedit.editable = true
	
	color_picker_1.disabled = false
	color_picker_2.disabled = false
	color_reset_button.disabled = false
	
	percentage_toggle.disabled = false
	completed_toggle.disabled = false

func show_tracker() -> void:
	progress_window.visible = true
	
func hide_tracker() -> void:
	progress_window.visible = false
