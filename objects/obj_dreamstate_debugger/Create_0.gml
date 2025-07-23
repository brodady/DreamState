manager = __DreamState_GetDebugManager();
view = dbg_view("DreamState", true);

history_text = "(No FSM selected)";
current_state_text = "State: (None)";
inspector_text = "";
last_selected_fsm_id = noone;
sections = {};
owner_options_string = "None:0"; 
selected_owner_index = 0;
instance_options_string = "None:0"; 
selected_instance_index = 0;
inspector_section_list = []; 

// Caching to know when to rebuild the UI
last_owner_list = [];
last_selected_owner_index = -1;

copy_inspector_to_clipboard = function() {
    if (is_string(inspector_text)) {
        clipboard_set_text(inspector_text);
        show_debug_message("Inspector text copied to clipboard.");
    }
}

copy_history_to_clipboard = function() {
    if (is_string(history_text)) {
        clipboard_set_text(history_text);
        show_debug_message("History text copied to clipboard.");
    }
}


__build_inspector_ui = function(_struct_to_render, _visited = []) {
    // --- Circular Reference Check ---
    if (array_contains(_visited, _struct_to_render)) { return; }
    array_push(_visited, _struct_to_render);

    var _keys = variable_struct_get_names(_struct_to_render);
    array_sort(_keys, true);

    var _containers = []; // For two-pass rendering of nested data

    // --- Pass 1: Render editable fields and simple watches ---
    for (var i = 0; i < array_length(_keys); i++) {
        var _key = _keys[i];
        if (_key == "fsm") continue; // Skip the internal FSM reference
        
        var _value = _struct_to_render[$ _key];
        
        if (is_struct(_value) || is_array(_value)) {
            array_push(_containers, {key: _key, value: _value});
            continue;
        }

        if (is_real(_value)) {
            // Check if it's an integer
            if (frac(_value) == 0) {
                
                dbg_text_input(ref_create(_struct_to_render, _key), _key + ":", "i");
            } else {
                
                dbg_text_input(ref_create(_struct_to_render, _key), _key + ":", "f");
            }
        } else if (is_string(_value)) {
            
            dbg_text_input(ref_create(_struct_to_render, _key), _key + ":", "s");
        }
        // watch for other types like booleans
        else {
            dbg_watch(ref_create(_struct_to_render, _key), _key + ":");
        }
    }

    // --- Pass 2: Create read-only sections for nested data ---
    for (var i = 0; i < array_length(_containers); i++) {
        var _item = _containers[i];
        var _key = _item.key;
        var _value = _item.value;

        var _section = dbg_section(_key, false);
        array_push(inspector_section_list, _section); 
        dbg_watch(ref_create(_struct_to_render, _key), "data:");
    }

    array_pop(_visited);
}