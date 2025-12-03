extends Control

var game_data : Dictionary
var url : String
var game_index : int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize text
	initialize_text()
	
	# Initialize subwindow transparency
	$"Single Game Window/PanelContainer/Control/Chosen Game".modulate.a = 0
	
	$"Single Game Window".visible = false
	
	$HTTPRequest.request_completed.connect(_on_request_completed)

func initialize_text():
	$"Single Game Window/PanelContainer/Control/Chosen Game/game_text".text = "[center][wave]Loading[/wave][/center]"
	$"Single Game Window/PanelContainer/Control/Total/total_text".text = "[center][wave]Loading[/wave][/center]"
	
	$"Single Game Window/PanelContainer/Control/Total/total_progress".position.x = -1000
	$"Single Game Window/PanelContainer/Control/Chosen Game/game_progress".position.x = -1000

func _on_launch_button_pressed() -> void:
	initialize_text()
	
	# Set URL
	url = "https://archipelago.gg/tracker/" + $"URL Line".text
	
	# Validate URL
	
	# Send http request
	$HTTPRequest.request(url)
	
	$"Single Game Window".visible = true
	$"Single Game Window/Error".visible = false
	
	$"Single Game Window/Timer".start()

func _on_request_completed(_result, _response_code, _headers, _body):
	if _response_code == 200:
		populate_data(_body)
	else:
		$"Single Game Window/Error".visible = true
		

func populate_data(_body):
	# Get the table, just the games no header or footer
	var table = _body.get_string_from_utf8().split('<tbody>')[1].split('</tbody>')[0]
	
	# Regular expressions... eww!
	
	## GAME DATA
	var regex = RegEx.new()
	regex.compile('<td.*?>(.|\n)*?</td>')
	
	# Number of games
	var game_count = regex.search_all(table).size()/7
	
	# Currently parsed game
	var current_game = ""
	
	# Column counter, 2 for game name
	var column = 0
	for result in regex.search_all(table):
		if column % 7 == 2:
			current_game = result.get_string().split('>')[1].split('<')[0].strip_edges().replace("&#39;", "'")
		elif column % 7 == 4:
			game_data[current_game] = result.get_string().split('>')[1].split('<')[0].strip_edges()
		column+=1
	
	## ALL DATA
	
	table = _body.get_string_from_utf8().split('<tfoot>')[1].split('</tfoot>')[0]
	
	regex.compile('<td.*?>(.|\n)*?</td>')
	var total_checks = regex.search_all(table)[3].get_string().split('>')[1].split('<')[0].strip_edges()
	
	populate_text(total_checks)
	

func _on_single_game_window_close_requested() -> void:
	$"Single Game Window".visible = false
	$"Single Game Window/Timer".stop()
	game_index = 0
	game_data.clear()

func populate_text(total_checks):
	## PROGRESS BAR
	var expression = Expression.new()
	expression.parse(total_checks+".0")
	
	$"Single Game Window/PanelContainer/Control/Total/total_progress".position.x = expression.execute() * 1000 - 1000+40
	
	## TEXT
	# Create text
	$"Single Game Window/PanelContainer/Control/Total/total_text".text = "[center]Total Checks: %s\n\n[table=2]" % total_checks
	
	# Single game text/progress
	if game_index >= game_data.keys().size():
			game_index = 0
	var chosen_game = game_data.keys()[game_index]
	
	expression.parse(game_data[chosen_game]+".0")
	$"Single Game Window/PanelContainer/Control/Chosen Game/game_text".text = "[center]%s: %s[/center]" % [chosen_game, game_data[chosen_game]]
	$"Single Game Window/PanelContainer/Control/Chosen Game/game_progress".position.x = expression.execute() * 1000 - 1000+40
	
	start_transition()
	
func _on_timer_timeout() -> void:
	$HTTPRequest.request(url)
	
func start_transition():
	var tween = get_tree().create_tween()
	var tween2 = get_tree().create_tween()
	if $"Single Game Window/PanelContainer/Control/Chosen Game".modulate.a == 0:
		tween.tween_property($"Single Game Window/PanelContainer/Control/Total", "modulate", Color(0,0,0,0), 2)
		tween2.tween_property($"Single Game Window/PanelContainer/Control/Chosen Game", "modulate", Color(1,1,1,1), 2)
	else:
		game_index += 1
		tween.tween_property($"Single Game Window/PanelContainer/Control/Chosen Game", "modulate", Color(0,0,0,0), 2)
		tween2.tween_property($"Single Game Window/PanelContainer/Control/Total", "modulate", Color(1,1,1,1), 2)
