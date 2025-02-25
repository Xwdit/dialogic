extends DialogicSubsystem

var choice_blocker = Timer.new()

func _ready():
	choice_blocker.one_shot = true
	DialogicUtil.update_timer_process_callback(choice_blocker)
	add_child(choice_blocker)

####################################################################################################
##					STATE
####################################################################################################

func clear_game_state():
	hide_all_choices()

func load_game_state():
	pass

####################################################################################################
##					MAIN METHODS
####################################################################################################

func hide_all_choices() -> void:
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		node.hide()
		if node.is_connected('button_up', self.choice_selected):
			node.disconnect('button_up', self.choice_selected)

func show_current_choices() -> void:
	hide_all_choices()
	var button_idx = 1
	for choice_index in get_current_choice_indexes():
		var choice_event = dialogic.current_timeline_events[choice_index]
		# check if condition is false
		if not choice_event.Condition.is_empty() and not dialogic.execute_condition(choice_event.Condition):
			if choice_event.IfFalseAction == DialogicChoiceEvent.IfFalseActions.DEFAULT:
				choice_event.IfFalseAction = DialogicUtil.get_project_setting('dialogic/choices/def_false_behaviour', 0)
			
			# check what to do in this case
			if choice_event.IfFalseAction == DialogicChoiceEvent.IfFalseActions.DISABLE:
				show_choice(button_idx, choice_event.get_translated_text(), false, choice_index)
				button_idx += 1
		# else just show it
		else:
			show_choice(button_idx, choice_event.get_translated_text(), true, choice_index)
			button_idx += 1
	
	if typeof(DialogicUtil.get_project_setting('dialogic/choices/delay')) != TYPE_FLOAT:
		choice_blocker.start(DialogicUtil.get_project_setting('dialogic/choices/delay', 0.2).to_float())
	else:
		choice_blocker.start(DialogicUtil.get_project_setting('dialogic/choices/delay', 0.2))


func show_choice(button_index:int, text:String, enabled:bool, event_index:int) -> void:
	var idx = 1
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		if !node.get_parent().is_visible_in_tree():
			continue
		if (node.choice_index == button_index) or (idx == button_index and node.choice_index == -1):
			node.show()
			if dialogic.has_subsystem('VAR'):
				node.text = dialogic.VAR.parse_variables(text)
			else:
				node.text = text
			
			if idx == 1 and DialogicUtil.get_project_setting('dialogic/choices/autofocus_first', true):
				node.grab_focus()
			
			if DialogicUtil.get_project_setting('dialogic/choices/hotkey_behaviour', 0) == 1 and idx < 10:
				var shortcut = Shortcut.new()
				var input_key = InputEventKey.new()
				input_key.scancode = OS.find_keycode_from_string(str(idx))
				shortcut.shortcut = input_key
				node.shortcut = shortcut
			
			node.disabled = not enabled
			node.button_up.connect(choice_selected.bind(event_index))
			
		if node.choice_index > 0:
			idx = node.choice_index
		idx += 1

####################################################################################################
##					HELPERS
####################################################################################################
func choice_selected(event_index:int) -> void:
	if Dialogic.paused or not choice_blocker.is_stopped():
		return
	hide_all_choices()
	dialogic.current_state = dialogic.states.IDLE
	dialogic.handle_event(event_index)

## QUESTION/CHOICES
func is_question(index:int) -> bool:
	if dialogic.current_timeline_events[index] is DialogicTextEvent:
		if len(dialogic.current_timeline_events)-1 != index:
			if dialogic.current_timeline_events[index+1] is DialogicChoiceEvent:
				return true
	return false

func get_current_choice_indexes() -> Array:
	var choices = []
	var evt_idx = dialogic.current_event_idx
	var ignore = 0
	while true:
		
		evt_idx += 1
		if evt_idx >= len(dialogic.current_timeline_events):
			break
		if dialogic.current_timeline_events[evt_idx] is DialogicChoiceEvent:
			if ignore == 0:
				choices.append(evt_idx)
			ignore += 1
		elif dialogic.current_timeline_events[evt_idx].can_contain_events:
			ignore += 1
		else:
			if ignore == 0:
				break
		
		if dialogic.current_timeline_events[evt_idx] is DialogicEndBranchEvent:
			ignore -= 1
	return choices
