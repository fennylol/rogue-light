extends Node

const ARCHIVIST = preload("res://world/noblemen/thearchivist.gd")

static func parse_command_string(input: String) -> Dictionary:
	# validate input pattern matches "/command -option[arg1,arg2,arg3]"
	var pattern = '^/([a-zA-Z]+)((?:\\s+-[a-zA-Z0-9_]+(?:\\[[^\\]]+\\])?)+)?$'
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var result = regex.search(input)
	if not result: return {"error": input+" is not in the form of /command -option[arg1,arg2,arg3]"}
	
	var command = result.get_string(1)
	var options_string = result.get_string(2)
	
	var options = {}
	var option_pattern = "-([a-zA-Z]+)(?:\\[([^\\]]+)\\])?"
	var option_regex = RegEx.new()
	option_regex.compile(option_pattern)
	
	for option_match in option_regex.search_all(options_string):
		var option_name = option_match.get_string(1)
		var option_data = option_match.get_string(2).split(",") if option_match.get_string(2) else []
		#options.push_back({"option_name": option_name, "option_data": option_data})
		options[option_name] = option_data
	
	var output_dict = {"command_name": command, "options": options}
	# parse complete 
	
	# validate input command and options exist and are valid
	var command_dict: Dictionary = ARCHIVIST.COMMANDS
	if command_dict.has(output_dict.command_name):
		for option in output_dict.options:
			if not command_dict[output_dict.command_name]["accepted_options"].has(option): 
				return {"error": option+" is not a valid option for /"+output_dict.command_name}
	else: return {"error":output_dict.command_name+" is not a valid command"}
	return output_dict 
