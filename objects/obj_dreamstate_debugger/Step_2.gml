// --- 1. Group all registered FSMs by their owner's object type ---
var _all_instances = manager.registered_fsms;
var _fsms_by_object = {}; 
var _owner_names = []; 

for (var i = 0; i < array_length(_all_instances); i++) {
    var _fsm = _all_instances[i];
    if (!is_struct(_fsm) || !instance_exists(_fsm.owner)) continue;
    
    var _obj_name = object_get_name(_fsm.owner.object_index);
    if (!variable_struct_exists(_fsms_by_object, _obj_name)) {
        _fsms_by_object[$ _obj_name] = [];
        array_push(_owner_names, _obj_name);
    }
    array_push(_fsms_by_object[$ _obj_name], _fsm);
}
array_sort(_owner_names, true);

// --- 2. Rebuild the Owner dropdown if the list of object types has changed ---
var _rebuild_owners = (string(_owner_names) != string(last_owner_list));
if (_rebuild_owners) {
    if (variable_struct_exists(sections, "owner_selector")) && (dbg_section_exists(sections.owner_selector)) dbg_section_delete(sections.owner_selector);
    
    owner_options_string = "All Objects:0";
    for (var i = 0; i < array_length(_owner_names); i++) {
        owner_options_string += "," + _owner_names[i] + ":" + string(i + 1);
    }
    
    sections.owner_selector = dbg_section("Owner Object");
    dbg_drop_down(ref_create(id, "selected_owner_index"), owner_options_string, "Select Type:");
    last_owner_list = _owner_names;
}

// --- 3. Determine which list of instances to show ---
var _instances_to_show = [];
selected_owner_index = clamp(selected_owner_index, 0, array_length(_owner_names));

if (selected_owner_index == 0) { // "All Objects"
    _instances_to_show = _all_instances;
} else {
    var _selected_obj_name = _owner_names[selected_owner_index - 1];
    _instances_to_show = _fsms_by_object[$ _selected_obj_name];
}

// --- 4. Rebuild the Instance dropdown if the owner selection has changed ---
if (selected_owner_index != last_selected_owner_index) {
    if (variable_struct_exists(sections, "instance_selector")) && (dbg_section_exists(sections.instance_selector)) dbg_section_delete(sections.instance_selector);
    
    var _inst_options = "None:0";
    for (var i = 0; i < array_length(_instances_to_show); i++) {
        _inst_options += ",Instance #" + string(_instances_to_show[i].owner.id) + ":" + string(i + 1);
    }
    instance_options_string = _inst_options;

    sections.instance_selector = dbg_section("Instances");
    dbg_drop_down(ref_create(id, "selected_instance_index"), instance_options_string, "Select Inst:");
    last_selected_owner_index = selected_owner_index;
}

// --- 5. Determine the final selected FSM ---
var _selected_fsm = noone;
selected_instance_index = clamp(selected_instance_index, 0, array_length(_instances_to_show));
if (selected_instance_index > 0) {
    _selected_fsm = _instances_to_show[selected_instance_index - 1];
}

// --- 6. Rebuild UI only when the FSM selection changes ---
manager.selected_fsm = _selected_fsm;
var _fsm_id = (_selected_fsm != noone) ? _selected_fsm.owner.id : noone;

if (_fsm_id != last_selected_fsm_id) {
    // --- Clean up all previously created sections ---
    for (var i = 0; i < array_length(inspector_section_list); i++) {
        var _section = inspector_section_list[i];
        if (dbg_section_exists(_section)) {
            dbg_section_delete(_section);
        }
    }
    array_resize(inspector_section_list, 0);
    
    // Also delete the main history section
    if (variable_struct_exists(sections, "history")) && (dbg_section_exists(sections.history)) dbg_section_delete(sections.history);

    // --- Build the new inspectors if an FSM is selected ---
    if (_selected_fsm != noone) {
        // A. --- CONTEXT INSPECTOR (Editable) ---
        var _context_inspector_section = dbg_section("Context Inspector");
        array_push(inspector_section_list, _context_inspector_section);
        // Initial call to the recursive UI builder
        __build_inspector_ui(_selected_fsm.context);

        // B. --- STATE DETAILS INSPECTOR (Read-only) ---
        var _state_details_section = dbg_section("Current State Details");
        array_push(inspector_section_list, _state_details_section);
        
        // We use dbg_watch with a ref to make this text update live
        dbg_watch(ref_create(id, "current_state_text"), "Current State:");
        
        // Other read-only details about the current state can be added here
        // For example, using dbg_text for static info or dbg_watch for dynamic info
        var _state_config = _selected_fsm.processedStates[$ string(_selected_fsm.get_current_state())];
        if (variable_struct_exists(_state_config, "parent")) {
            var parent_id = _state_config.parent;
            dbg_text($"Parent State: {_selected_fsm.__get_state_name(parent_id)} (ID: {parent_id})");
        }

    }

    // C. --- TRANSITION HISTORY ---
    sections.history = dbg_section("Transition History");
	dbg_button("Copy History", copy_history_to_clipboard); // Add this button back
	dbg_text_separator(); // Add a line for clean formatting
	dbg_text(ref_create(id, "history_text"));
    
    last_selected_fsm_id = _fsm_id;
}

// --- 7. Update dynamic text variables every frame ---
// This part is now much smaller, only for text that can't use a direct ref.
if (_selected_fsm != noone) {
    // Update the state name text
    var _state_id = _selected_fsm.get_current_state();
    current_state_text = $"{_selected_fsm.__get_state_name(_state_id)} (ID: {_state_id})";

    // Update the history text block
    var _history = _selected_fsm.history;
    var _history_string_builder = "";
    for (var i = array_length(_history) - 1; i >= 0; i--) {
        var _entry = _history[i];
        var _time_str = string_format(floor(_entry.timestamp / 1000), 0, 0) + "." + string_format(_entry.timestamp mod 1000, 3, 0);
        _history_string_builder += $"[{_time_str}s] {_entry.name}\n";
    }
    history_text = (_history_string_builder == "") ? "(No history yet)" : _history_string_builder;
    
} else {
    current_state_text = "(None)";
    history_text = "(No instance selected)";
}