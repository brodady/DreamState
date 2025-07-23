// DreamState
// Script: DreamStatePool.gml 

function DreamPool(_definition, _grid, _state_column_index) constructor {
    definition = _definition;
    grid = _grid;
    state_col = _state_column_index;
    states = definition.states;
    __state_on_step_chains = {};

    __build_state_chain = function(_state_id_str) {
        var _chain = [];
        var _current_id = real(_state_id_str);
        while (variable_struct_exists(states, string(_current_id))) {
            var _config = states[$ string(_current_id)];
            if (variable_struct_exists(_config, "onStep")) {
                var _prop = _config.onStep;
                var _func = is_struct(_prop) ? _prop.func : _prop;
                array_insert(_chain, 0, _func);
            }
            if (variable_struct_exists(_config, "parent")) {
                _current_id = _config.parent;
            } else { break; }
        }
        return _chain;
    }

    entities_in_state = {};
    var _h = ds_grid_height(grid);
    for (var i = 0; i < _h; i++) {
        var _state_id = grid[# state_col, i];
        if (_state_id == undefined) continue;
        var _state_id_str = string(_state_id);
        if (!variable_struct_exists(entities_in_state, _state_id_str)) {
            entities_in_state[$ _state_id_str] = ds_list_create();
            __state_on_step_chains[$ _state_id_str] = __build_state_chain(_state_id_str);
        }
        ds_list_add(entities_in_state[$ _state_id_str], i);
    }

    destroy = function() {
        var _state_keys = variable_struct_get_names(entities_in_state);
        for (var i = 0; i < array_length(_state_keys); i++) {
            ds_list_destroy(entities_in_state[$ _state_keys[i]]);
        }
    }

	update = function() {
	    if (!ds_exists(grid, ds_type_grid)) { return; }

	    var _grid = grid;
	    var _state_keys = variable_struct_get_names(entities_in_state);
	    for (var i = 0; i < array_length(_state_keys); i++) {
	        var _state_id_str = _state_keys[i];
	        var _chain = __state_on_step_chains[$ _state_id_str];
	        var _chain_len = array_length(_chain);
	        if (_chain_len == 0) continue;

	        var _list = entities_in_state[$ _state_id_str];
	        var _list_size = ds_list_size(_list);
        
	        for (var j = _list_size - 1; j >= 0; j--) { 
                var _row_index = _list[| j]; 
	            for (var k = 0; k < _chain_len; k++) {
	        
	                script_execute(_chain[k], _grid, _row_index, self);
	            }
	        }
	    }
	}
    
    change_state = function(_row, _new_state_id, _event_data = undefined) {
        var _old_state_id = grid[# state_col, _row];
        if (_old_state_id == _new_state_id) return;
        
        var _old_state_str = string(_old_state_id);
        var _new_state_str = string(_new_state_id);
        
        if (variable_struct_exists(entities_in_state, _old_state_str)) {
            var _list = entities_in_state[$ _old_state_str];
            var _index = ds_list_find_index(_list, _row);
            if (_index != -1) ds_list_delete(_list, _index);
        }
        
        if (!variable_struct_exists(entities_in_state, _new_state_str)) {
            entities_in_state[$ _new_state_str] = ds_list_create();
            __state_on_step_chains[$ _new_state_str] = __build_state_chain(_new_state_str);
        }
        ds_list_add(entities_in_state[$ _new_state_str], _row);
        
        leave_state(_row, _new_state_id, _event_data);
        grid[# state_col, _row] = _new_state_id;
        enter_state(_row, _old_state_id, _event_data);
    }
    
    enter_state = function(_row, _previous_state_id, _event_data = undefined) {
        var _state_id = grid[# state_col, _row];
        __ds_pool_execute_callback_hierarchical(self, _row, _state_id, "onEnter", "down", _previous_state_id, _event_data);
    }
    
    leave_state = function(_row, _next_state_id, _event_data = undefined) {
        var _state_id = grid[# state_col, _row];
        __ds_pool_execute_callback_hierarchical(self, _row, _state_id, "onLeave", "up", _next_state_id, _event_data);
    }
    
    fire_event = function(_row, _event_id, _event_data = undefined) {
        var _event_str = string(_event_id);
        var _check_state_id = grid[# state_col, _row];
        
        while (variable_struct_exists(states, string(_check_state_id))) {
            var _config = states[$ string(_check_state_id)];
            if (variable_struct_exists(_config, "on") && variable_struct_exists(_config.on, _event_str)) {
                var _transition = _config.on[$ _event_str];
                var _can_transition = true;
                if (variable_struct_exists(_transition, "guard")) {
                    _can_transition = _transition.guard(grid, _row);
                }
                if (_can_transition) {
                    if (variable_struct_exists(_transition, "action")) _transition.action(grid, _row, _event_data);
                    if (variable_struct_exists(_transition, "target")) change_state(_row, _transition.target, _event_data);
                    return;
                }
            }
            if (variable_struct_exists(_config, "parent")) {
                _check_state_id = _config.parent;
            } else { break; }
        }
    }
}

function __ds_pool_execute_callback_hierarchical(_pool, _row_index, _state_id, _callback_name, _direction, _arg1 = undefined, _arg2 = undefined) {
    var _hierarchy_chain = [];
    var _current_id = _state_id;
    while (variable_struct_exists(_pool.states, string(_current_id))) {
        var _config = _pool.states[$ string(_current_id)];
        array_push(_hierarchy_chain, _config);
        if (variable_struct_exists(_config, "parent")) {
            _current_id = _config.parent;
        } else { break; }
    }
    if (_direction == "down") {
        array_reverse(_hierarchy_chain);
    }
    
    for (var i = 0; i < array_length(_hierarchy_chain); i++) {
        var _config = _hierarchy_chain[i];
        if (variable_struct_exists(_config, _callback_name)) {
            var _callback_prop = _config[$ _callback_name];
            var _callback = is_struct(_callback_prop) ? _callback_prop.func : _callback_prop;
            
            try {
                script_execute(_callback, _pool.grid, _row_index, _arg1, _arg2);
            } catch(_ex) {
                __DreamState_Error($"Callback error in '{_callback_name}' for pseudo-object at row {_row_index}.\nOriginal error: {_ex.message}\n{_ex.longMessage}");
            }
        }
    }
}