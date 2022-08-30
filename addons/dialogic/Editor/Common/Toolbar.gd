@tool
extends HBoxContainer

signal toggle_editor_view(mode:String)
signal create_timeline
signal play_timeline

var current_version := ""

func _ready():
	# Update available
	%UpdateAvailable.visible = false
	%UpdateAvailable.button_up.connect(_open_website.bind("https://dialogic.coppolaemilio.com/update"))
	%UpdateAvailable.icon = get_theme_icon("Warning", "EditorIcons")
	%UpdateAvailable.flat = true
	
	# Donate button
	%Donate.icon = get_theme_icon("Heart", "EditorIcons")
	%Donate.button_up.connect(_open_website.bind("https://dialogic.coppolaemilio.com/donate"))
	%Donate.focus_mode = 0
	%Donate.flat = true
	
	# Version
	%Version.set("custom_colors/font_color", get_theme_color("disabled_font_color", "Editor"))
	var config := ConfigFile.new()
	var err := config.load("res://addons/dialogic/plugin.cfg")
	if err == OK:
		current_version = config.get_value("plugin", "version")
		%Version.text = "v" + config.get_value("plugin", "version")
		%Version/HTTPRequest.request_completed.connect(_version_request_completed)
		%Version/HTTPRequest.request(
			"http://dialogic.coppolaemilio.com/latest-version/"
		)
			
	
	
	$PlayTimeline.icon = get_theme_icon("PlayScene", "EditorIcons")
	$PlayTimeline.button_up.connect(_on_play_timeline)
	
	$AddTimeline.icon = load("res://addons/dialogic/Editor/Images/Toolbar/add-timeline.svg")
	%ResourcePicker.get_suggestions_func = [self, 'suggest_resources']
	%ResourcePicker.resource_icon = get_theme_icon("GuiRadioUnchecked", "EditorIcons")
	$Settings.icon = get_theme_icon("Tools", "EditorIcons")
	
	
	$ToggleVisualEditor.button_up.connect(_on_toggle_visual_editor_clicked)
	update_toggle_button()


## Update checking
func _version_request_completed(result, response_code, headers, body):
	var latest_version: String = body.get_string_from_utf8()
	if current_version.to_lower() != latest_version.to_lower():
		%UpdateAvailable.visible = true
		print('check for updates!')


func _open_website(url:String) -> void:
	OS.shell_open(url)


################################################################################
##							HELPERS
################################################################################

func set_resource_saved() -> void:
	if %ResourcePicker.current_value.ends_with(("(*)")):
		%ResourcePicker.set_value(%ResourcePicker.current_value.trim_suffix("(*)"))

func set_resource_unsaved() -> void:
	if not %ResourcePicker.current_value.ends_with(("(*)")):
		%ResourcePicker.set_value(%ResourcePicker.current_value +"(*)")

func is_current_unsaved() -> bool:
	if %ResourcePicker.current_value and %ResourcePicker.current_value.ends_with('(*)'):
		return true
	return false

################################################################################
##							BASICS
################################################################################

func _on_AddTimeline_pressed() -> void:
	emit_signal("create_timeline")


func _on_AddCharacter_pressed() -> void:
	find_parent('EditorView').godot_file_dialog(
		get_parent().get_node("CharacterEditor").new_character,
		'*.dch; DialogicCharacter',
		EditorFileDialog.FILE_MODE_SAVE_FILE,
		'Save new Character',
		'New_Character',
		true
	)


func suggest_resources(filter:String) -> Dictionary:
	var suggestions = {}
	for i in DialogicUtil.get_project_setting('dialogic/editor/last_resources', []):
		if i.ends_with('.dtl'):
			suggestions[DialogicUtil.pretty_name(i)] = {'value':i, 'tooltip':i, 'editor_icon': ["TripleBar", "EditorIcons"]}
		elif i.ends_with('.dch'):
			suggestions[DialogicUtil.pretty_name(i)] = {'value':i, 'tooltip':i, 'icon':load("res://addons/dialogic/Editor/Images/Resources/character.svg")}
	return suggestions


func resource_used(path:String) -> void:
	var used_resources:Array = DialogicUtil.get_project_setting('dialogic/editor/last_resources', [])
	if path in used_resources:
		used_resources.erase(path)
	used_resources.push_front(path)
	ProjectSettings.set_setting('dialogic/editor/last_resources', used_resources)


################################################################################
##							TIMELINE_MODE
################################################################################

func load_timeline(timeline_path:String) -> void:
	resource_used(timeline_path)
	%ResourcePicker.set_value(DialogicUtil.pretty_name(timeline_path))
	%ResourcePicker.resource_icon = get_theme_icon("TripleBar", "EditorIcons")
	show_timeline_tool_buttons()


func _on_play_timeline() -> void:
	emit_signal('play_timeline')
	$PlayTimeline.release_focus()

func show_timeline_tool_buttons() -> void:
	$PlayTimeline.show()
	$ToggleVisualEditor.show()

func hide_timeline_tool_buttons() -> void:
	$PlayTimeline.hide()
	$ToggleVisualEditor.hide()
################################################################################
##							CHARACTER_MODE
################################################################################

func load_character(character_path:String) -> void:
	resource_used(character_path)
	%ResourcePicker.set_value(DialogicUtil.pretty_name(character_path))
	%ResourcePicker.resource_icon = load("res://addons/dialogic/Editor/Images/Resources/character.svg")
	hide_timeline_tool_buttons()


func _on_ResourcePicker_value_changed(property_name, value) -> void:
	if value:
		DialogicUtil.get_dialogic_plugin().editor_interface.inspect_object(load(value))


################################################################################
##							EDITING MODE
################################################################################

func _on_toggle_visual_editor_clicked() -> void:
	var _mode := 'visual'
	if DialogicUtil.get_project_setting('dialogic/editor_mode', 'visual') == 'visual':
		_mode = 'text'
	ProjectSettings.set_setting('dialogic/editor_mode', _mode)
	ProjectSettings.save()
	emit_signal('toggle_editor_view', _mode)
	update_toggle_button()
	

func update_toggle_button() -> void:
	$ToggleVisualEditor.icon = get_theme_icon("ThemeDeselectAll", "EditorIcons")
	# Have to make this hack for the button to resize properly {
	$ToggleVisualEditor.size = Vector2(0,0)
	await get_tree().process_frame
	$ToggleVisualEditor.size = Vector2(0,0)
	# } End of hack :)
	if DialogicUtil.get_project_setting('dialogic/editor_mode', 'visual') == 'text':
		$ToggleVisualEditor.text = 'Visual Editor'
	else:
		$ToggleVisualEditor.text = 'Text Editor'
