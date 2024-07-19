extends TextEdit


var COMMAND_HISTORY: Array[String] = []
var CH_pointer = -1
var your_input: String
var DUKE = TheDuke

func _ready():
	# Make it single-line
	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	context_menu_enabled = false
	shortcut_keys_enabled = true
	
	# Disable multiline input
	virtual_keyboard_enabled = false
	
	# Set scrolling behavior
	scroll_fit_content_height = true
	scroll_vertical = false
	scroll_horizontal = true
	
	# Connect the text change signal
	text_changed.connect(_on_text_changed)


func _process(delta):
	if get_parent().visible:
		if Input.is_action_just_pressed("DEV_command") or Input.is_action_just_pressed("submit"):
			var command = text.strip_edges()
			COMMAND_HISTORY.push_front(command)
			text = ""
			your_input = ""
			CH_pointer = -1
		
		var i = get_caret_column()
		if Input.is_action_just_pressed("look_up"):
			if CH_pointer == -1: your_input = text
			if CH_pointer < COMMAND_HISTORY.size()-1:
				CH_pointer += 1 
				text = COMMAND_HISTORY[CH_pointer]
		elif Input.is_action_just_pressed("look_down"):
			if CH_pointer >= 0:
				CH_pointer -= 1 
				text = your_input if CH_pointer == -1 else COMMAND_HISTORY[CH_pointer]
		set_caret_column(i)

func _on_text_changed():
	# Remove any newline characters
	var i = get_caret_column()
	text = text.replace("\n", "")

	# Move caret to the end
	set_caret_column(i)
   

func _gui_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ENTER:
			# Prevent new line on Enter key
			accept_event()


func set_caret_to_end():
	var last_line = get_line_count() - 1
	var last_column = get_line(last_line).length()
	set_caret_line(last_line)
	set_caret_column(last_column)
