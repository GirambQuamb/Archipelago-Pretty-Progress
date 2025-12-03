extends Control

### Global variables ###
var url : String # Multiworld tracker URL

var slot_data : Dictionary # Slot info (player, game, progress)
var slot_index : int = 0 # Used for progressing through slots

enum Display_Mode {PLAYER, GAME, BOTH} # Whether to show players, games or both
var display_mode : int = 0 # TODO - Actually give the option to show both...

### Node variables ###

## Helpers ##
@export var http_request : HTTPRequest
@export var timer : Timer # Used for spacing HTTPRequests and transitions

## Launch Menu ##
@export var display_selection : MenuButton # Lets the user choose how to display slot names
@export var launch_button : Button # Launches the progress window
@export var url_lineedit : LineEdit # User types the end of the tracker url here

## Progress Window ##
@export var progress_window : Window # Second window that displays the progress bar
@export var display_parent_a : Control # Parent for the two progress displays
@export var display_parent_b : Control
@export var display_text_a : RichTextLabel # Text for the two progress displays
@export var display_text_b : RichTextLabel
@export var progress_bar_a : ColorRect # Progress bar for the two progress displays
@export var progress_bar_b : ColorRect
@export var display_error : ColorRect # Error message

# Initialize the scene
func _ready() -> void:
	# Initialize text
	initialize_text()
	
	# Initialize subwindow transparency
	display_parent_a.modulate.a = 0
	
	progress_window.visible = false
	
	http_request.request_completed.connect(_on_request_completed)
	
	display_selection.get_popup().id_pressed.connect(_on_menu_button_pressed)

func _on_menu_button_pressed(id : int) -> void:
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
	
	display_selection.disabled = true
	launch_button.disabled = true
	url_lineedit.editable = false
	
	# Set URL
	url = "https://archipelago.gg/tracker/" + url_lineedit.text
	
	# Validate URL
	## Used to have something here... but that was before git lol
	
	# Send http request
	http_request.request(url)
	
	progress_window.visible = true
	display_error.visible = false
	
	timer.start()

func _on_request_completed(_result, _response_code, _headers, _body):
	if _response_code == 200: # idk what this response code means but it works
		populate_data(_body)
	else:
		display_error.visible = true
		

func populate_data(_body):
	# Get the table, just the games no header or footer
	var table = _body.get_string_from_utf8().split('<tbody>')[1].split('</tbody>')[0]
	
	# Regular expressions... eww!
	
	## GAME DATA
	var regex = RegEx.new()
	regex.compile('<td.*?>(.|\n)*?</td>')
	
	# Number of games
	var game_count = regex.search_all(table).size()/7
	
	# Currently parsed slot
	var current_slot = ""
	# Currently parsed slot's player
	var current_player = ""
	# Currently parsed slot's game
	var current_game = ""
	# Currently parsed slot's progress
	var current_progress = ""
	
	
	# Column counter, 1 for player, 2 for game, 4 for progress
	var column = 0
	for result in regex.search_all(table):
		if column %7 == 0:
			current_slot = result.get_string().split('>')[2].split('<')[0].strip_edges().replace("&#39;", "'")
		elif column %7 == 1:
			current_player = result.get_string().split('>')[1].split('<')[0].strip_edges().replace("&#39;", "'")
		elif column % 7 == 2:
			current_game = result.get_string().split('>')[1].split('<')[0].strip_edges().replace("&#39;", "'")
		elif column % 7 == 4:
			current_progress = result.get_string().split('>')[1].split('<')[0].strip_edges()
		
		slot_data[current_slot] = {
			"player": current_player,
			"game": current_game,
			"progress": current_progress
		}
		column+=1
	
	## ALL DATA
	table = _body.get_string_from_utf8().split('<tfoot>')[1].split('</tfoot>')[0]
	
	regex.compile('<td.*?>(.|\n)*?</td>')
	var total_checks = regex.search_all(table)[3].get_string().split('>')[1].split('<')[0].strip_edges()
	
	slot_data["TOTAL"] = {
		"player": "Total Checks",
		"game": "Total Checks",
		"progress": total_checks
	}
	
	populate_text()
	

func reset_data():
	progress_window.visible = false
	timer.stop()
	slot_index = 0
	slot_data.clear()

func _on_single_game_window_close_requested() -> void:
	reset_data()
	
	launch_button.disabled = false
	display_selection.disabled = false
	url_lineedit.editable = true

func populate_text():
	start_transition()
	
	# Expression for math
	var expression = Expression.new()
	
	# Choose a slot to display
	var chosen_slot = slot_data.keys()[slot_index % slot_data.keys().size()]
	
	if slot_index % 2 == 0:
		## NODE 1
		expression.parse(slot_data[chosen_slot]["progress"]+".0")
		match display_mode:
			Display_Mode.PLAYER:
				display_text_a.text = "[center]%s: %s[/center]" % [slot_data[chosen_slot]["player"], slot_data[chosen_slot]["progress"]]
			Display_Mode.GAME:
				display_text_a.text = "[center]%s: %s[/center]" % [slot_data[chosen_slot]["game"], slot_data[chosen_slot]["progress"]]
		progress_bar_a.position.x = expression.execute() * 1000 - 1000+40
	else:
		## NODE 2
		expression.parse(slot_data[chosen_slot]["progress"]+".0")
		match display_mode:
			Display_Mode.PLAYER:
				display_text_b.text = "[center]%s: %s[/center]" % [slot_data[chosen_slot]["player"], slot_data[chosen_slot]["progress"]]
			Display_Mode.GAME:
				display_text_b.text = "[center]%s: %s[/center]" % [slot_data[chosen_slot]["game"], slot_data[chosen_slot]["progress"]]
		progress_bar_b.position.x = expression.execute() * 1000 - 1000+40
	
	# Move to the next slot
	slot_index += 1

func _on_timer_timeout() -> void:
	http_request.request(url)
	
func start_transition():
	var tween = get_tree().create_tween()
	var tween2 = get_tree().create_tween()
	if display_parent_a.modulate.a == 0:
		tween.tween_property(display_parent_b, "modulate", Color(0,0,0,0), 2)
		tween2.tween_property(display_parent_a, "modulate", Color(1,1,1,1), 2)
	else:
		tween.tween_property(display_parent_a, "modulate", Color(0,0,0,0), 2)
		tween2.tween_property(display_parent_b, "modulate", Color(1,1,1,1), 2)
