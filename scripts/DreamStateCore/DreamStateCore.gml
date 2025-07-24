// DreamState Hierarchical State Machine Library
// By: Mr. Giff
// ver: 0.4.3 (Fixed internal timer bug)
// lic: MIT

// ======================================================================
//                               MAIN API
// ======================================================================

/// @function DreamState(_definition_id, _setup_callback)
/// @description 
///   Creates and caches a state machine definition.
/// @param {String} _definition_id 
///   A unique string identifier for this definition.
/// @param {Function} _setup_callback 
///   A function that configures the new definition.
function DreamState(_definition_id, _setup_callback) 
{
    var _ds = __DreamStateGlobal();
    
    if (variable_struct_exists(_ds.definitions, _definition_id)) {
        return _ds.definitions[$ _definition_id];
    }
    
    var _def = new DreamStateDefinition();
    _setup_callback(_def);
    
    _ds.definitions[$ _definition_id] = _def;
    return _def;
}

// ======================================================================
//                             CONSTRUCTORS
// ======================================================================

/// @function DreamStateDefinition(_config)
function DreamStateDefinition(_config = {}) constructor 
{
    __DreamStateInitDebugger();

    states = {};
    config = (_config == undefined) ? {} : _config;
    nameLookup = undefined;
    
    if (!variable_struct_exists(self.config, "time_unit")) {
        config.time_unit = DREAMSTATE_TIME.STEPS; 
    }
    
    /// @function setNames(_lookup_struct)
    /// @description Bind string names to state enums (optional for debugging)
    setNames = function(_lookup_struct) 
    {
        nameLookup = _lookup_struct;
        return self;
    }
    
    /// @function define(_state_id)
    /// @description Defines a new STATE. Takes a state id enum you define.
    define = function(_state_id) 
    {
        return new __DreamState_StateBuilder(self, _state_id);
    }

    /// @function create_instance(_owner, _initial_state, _context)
    /// @description Creates a DreamState instance. The "machine".
    create_instance = function(
        _owner_id, _initial_state_id, _context_struct = {}
    ) {
        var _instance = new DreamStateInstance(
            _owner_id, _initial_state_id, self, _context_struct
        );
    
        var _bind = function(_owner_id, _cfg, _name) 
		{
		    if (variable_struct_exists(_cfg, _name)) {
		        var _info = _cfg[$ _name];
		        if (is_struct(_info)) {
		            _cfg[$ _name + "Info"] = _info; 
		            
		            var _t = _info.type;
		            if (_t=="owner" || _t=="guard" || _t=="action") {
		                _cfg[$ _name] = method(_owner_id, _info.func);
		            } else {
		                _cfg[$ _name] = _info.func;
		            }
		        }
		    }
		};

        var _state_keys = variable_struct_get_names(self.states);

        // PASS 1: Clone state configs and bind callbacks
        for (var i = 0; i < array_length(_state_keys); i++) {
            var _key = _state_keys[i];
            var _orig_cfg = self.states[$ _key];
            var _new_cfg = deep_copy(_orig_cfg);
            
            _bind(_owner_id, _new_cfg, "onEnter");
            _bind(_owner_id, _new_cfg, "onStep");
            _bind(_owner_id, _new_cfg, "onLeave");
            _bind(_owner_id, _new_cfg, "onDraw");

            if (variable_struct_exists(_new_cfg, "on")) {
                var _event_keys = variable_struct_get_names(
                    _new_cfg.on
                );
                for (var j = 0; j < array_length(_event_keys); j++) {
                    var _event_key = _event_keys[j];
                    var _trans = _new_cfg.on[$ _event_key];
                    _bind(_owner_id, _trans, "guard");
					_bind(_owner_id, _trans, "action");
                }
            }
            
            _instance.processedStates[$ _key] = _new_cfg;
        }

        // PASS 2: Build cached hierarchy chains
        for (var i = 0; i < array_length(_state_keys); i++) {
            var _key = _state_keys[i];
            var _state_id = _instance.processedStates[$ _key].__state_id;
            var _chain = _instance.__build_hierarchy_chain(_state_id);
            _instance.processedStates[$ _key].__hierarchy = _chain;
        }

        // --- Final setup ---
        if (DREAMSTATE_STRICT_MODE) {
            if (!_instance.is_state_defined(_initial_state_id)) {
				try {
					var _state_str = variable_struct_exists(nameLookup, string(_initial_state_id));
	                var _err = "Attempted to create FSM with an initial "
	                         + $"state '{_state_str}' "
	                         + "that has not been defined.";
	                __DreamState_Error(_err);
	                return undefined;
				} catch(ex) {
					var _err = "Attempted to create FSM with an initial "
	                         + $"state {_initial_state_id}"
	                         + "that has not been defined.\n"
							 + " (Define names with nameLookup on your definition struct to not see numbers)";
	                __DreamState_Error(_err);
				}
            }
        }

        _instance.__enter_state(_initial_state_id, undefined, undefined);
        return _instance;
    }
}

/// @function __DreamState_StateBuilder(_definition, _state_id)
/// @desc Internal constructor for building a state's configuration.
/// @param {Struct} _definition The main FSM definition struct.
/// @param {Any} _state_id The unique ID for the state being built.
function __DreamState_StateBuilder(_definition, _state_id) constructor
{
    __definition = _definition;
    __config = { __state_id: _state_id };
    __state_id_str = string(_state_id);
    __definition.states[$ __state_id_str] = __config;

    // This internal builder remains unchanged.
    /// @ignore
    _create_callback_info = function(_callback, _type)
    {
        var _is_guard_or_action = (_type=="guard" || _type=="action");
        if (!is_method(_callback) && _is_guard_or_action) {
            return { type: "owner", func: _callback };
        }
        return { type: _type, func: _callback };
    }

    /// @function withParent(_parent_id)
    /// @desc Sets the parent state for this state.
    /// @param {Any} _parent_id The ID of the parent state.
    /// @return {Struct} Returns self for method chaining.
    withParent = function(_parent_id) {
        __config.parent = _parent_id; return self;
    }
    
    /// @function withData(_data_struct)
    /// @desc Attaches a custom data struct to this state.
    /// @param {Struct} _data_struct The data struct to attach.
    /// @return {Struct} Returns self for method chaining.
    withData = function(_data_struct) {
        __config.data = _data_struct; return self;
    }

    /// @function onEnterInOwner(_cb)
    /// @desc Sets the onEnter callback to execute in the owner's scope.
    /// @param {Function|String} _cb The callback or method name.
    /// @return {Struct} Returns self for method chaining.
    onEnterInOwner = function(_cb) {
        __config.onEnter = _create_callback_info(_cb, "owner");
        return self;
    }
    
    /// @function onStepInOwner(_cb)
    /// @desc Sets the onStep callback to execute in the owner's scope.
    /// @param {Function|String} _cb The callback or method name.
    /// @return {Struct} Returns self for method chaining.
    onStepInOwner  = function(_cb) {
        __config.onStep  = _create_callback_info(_cb, "owner");
        return self;
    }
    
    /// @function onLeaveInOwner(_cb)
    /// @desc Sets the onLeave callback to execute in the owner's scope.
    /// @param {Function|String} _cb The callback or method name.
    /// @return {Struct} Returns self for method chaining.
    onLeaveInOwner = function(_cb) {
        __config.onLeave = _create_callback_info(_cb, "owner");
        return self;
    }
    
    /// @function onDrawInOwner(_cb)
    /// @desc Sets the onDraw callback to execute in the owner's scope.
    /// @param {Function|String} _cb The callback or method name.
    /// @return {Struct} Returns self for method chaining.
    onDrawInOwner  = function(_cb) {
        __config.onDraw  = _create_callback_info(_cb, "owner");
        return self;
    }

    /// @function onEnterInFSM(_cb)
    /// @desc Sets the onEnter callback to execute in the FSM's scope.
    /// @param {Function} _cb The callback function.
    /// @return {Struct} Returns self for method chaining.
    onEnterInFSM = function(_cb) {
        __config.onEnter = _create_callback_info(_cb, "fsm");
        return self;
    }
    
    /// @function onStepInFSM(_cb)
    /// @desc Sets the onStep callback to execute in the FSM's scope.
    /// @param {Function} _cb The callback function.
    /// @return {Struct} Returns self for method chaining.
    onStepInFSM  = function(_cb) {
        __config.onStep  = _create_callback_info(_cb, "fsm");
        return self;
    }
    
    /// @function onLeaveInFSM(_cb)
    /// @desc Sets the onLeave callback to execute in the FSM's scope.
    /// @param {Function} _cb The callback function.
    /// @return {Struct} Returns self for method chaining.
    onLeaveInFSM = function(_cb) {
        __config.onLeave = _create_callback_info(_cb, "fsm");
        return self;
    }
    
    /// @function onDrawInFSM(_cb)
    /// @desc Sets the onDraw callback to execute in the FSM's scope.
    /// @param {Function} _cb The callback function.
    /// @return {Struct} Returns self for method chaining.
    onDrawInFSM  = function(_cb) {
        __config.onDraw  = _create_callback_info(_cb, "fsm");
        return self;
    }

    onEnter = onEnterInOwner;
    onStep  = onStepInOwner;
    onLeave = onLeaveInOwner;
    onDraw  = onDrawInOwner;

    /// @function onEvent(_event_id, _transition_config)
    /// @desc Defines a transition triggered by an event.
    /// @param {Any} _event_id The ID of the event to listen for.
    /// @param {Struct} _transition_config Struct with 'target', 'guard', 'action'.
    /// @return {Struct} Returns self for method chaining.
    onEvent = function(_event_id, _transition_config)
    {
        if (!variable_struct_exists(__config, "on")) __config.on = {};
        
        if (variable_struct_exists(_transition_config, "guard")) {
            _transition_config.guard = _create_callback_info(
                _transition_config.guard, "guard"
            );
        }
        if (variable_struct_exists(_transition_config, "action")) {
            _transition_config.action = _create_callback_info(
                _transition_config.action, "action"
            );
        }

        __config.on[$ string(_event_id)] = _transition_config;
        return self;
    }

    /// @function after(_duration, _event_id, [_is_recurring=false])
    /// @desc Creates a timer that fires an event upon entering this state.
    /// @param {Real} _duration Time in frames until the event fires.
    /// @param {Any} _event_id The ID of the event to fire.
    /// @param {Bool} [_is_recurring=false] Whether the timer should repeat.
    /// @return {Struct} Returns self for method chaining.
    after = function(_duration, _event_id, _is_recurring = false)
    {
        if (!variable_struct_exists(__config, "timersOnEnter")) {
            __config.timersOnEnter = [];
        }
        array_push(__config.timersOnEnter, {
            duration: _duration,
            event: _event_id,
            recurring: _is_recurring
        });
        return self;
    }
}

/// @function DreamStateInstance(_owner, _initial_state, _def, _context)
/// @desc Creates and manages a finite state machine (FSM) instance.
/// @param {Id.Instance} _owner_id The instance that owns this FSM.
/// @param {Any} _initial_state_id The ID of the starting state.
/// @param {Struct} _definition A pre-built FSM definition.
/// @param {Any} [_user_context] Optional user-defined context data.
function DreamStateInstance(
    _owner_id, _initial_state_id, _definition, _user_context
) constructor {
    owner = _owner_id;
    definition = _definition;
    context = _user_context;
    
    processedStates = {};
    stateStack = [_initial_state_id];
    history = [];
    __activeTimers = [];
    __nextTimerId = 0;
    __currentStateData = undefined;
    __stateHistory = {};

    if (DREAMSTATE_DEBUG_ENABLED) {
        DreamStateDebugRegisterFsm(self);
    }
    
    /// @function destroy()
    /// @desc Cleans up the FSM instance, primarily for debugging.
    destroy = function()
    {
        if (DREAMSTATE_DEBUG_ENABLED) {
            DreamStateDebugUnregisterFsm(self);
        }
        if (gc_is_enabled()) { gc_collect(); }
    }
    
    /// @function update()
    /// @desc Runs the 'onStep' logic for the current state hierarchy.
    /// Call this once per frame in a Step event.
    update = function() {
        __update_timers();
        var _current_state_id = get_current_state();
        var _ret = __DreamState_ExecuteCallbackHierarchical(
            self, _current_state_id, "onStep", "down", context, __currentStateData);
        if (_ret != undefined) {
            __change_state(_ret, undefined);
        }
    }
    
    /// @function draw()
    /// @desc Runs the 'onDraw' logic for the current state hierarchy.
    /// Call this once per frame in a Draw event.
    draw = function() {
        var _current_state_id = get_current_state();
        __DreamState_ExecuteCallbackHierarchical(
            self, _current_state_id, "onDraw", "down", context, __currentStateData);
    }
    
    /// @function fire(_event_id, [_event_data])
    /// @desc Fires an event, which may cause a state transition.
    /// @param {Any} _event_id The ID of the event to fire.
    /// @param {Any} [_event_data] Optional data to pass to callbacks.
    fire = function(_event_id, _event_data = undefined) {
        // Internal parameter _is_from_input is omitted from docs
        var _is_from_input = true; 
        if (_is_from_input && is_mouse_over_debug_overlay() && mouse_check_button_pressed(mb_left)) {
            return;
        }

        var _event_str = string(_event_id);
        var _check_state_id = get_current_state();
        var _config = processedStates[$ string(_check_state_id)];
        var _hierarchy = _config.__hierarchy;
        
        for (var i = 0; i < array_length(_hierarchy); i++) {
            var _current_config = _hierarchy[i];
            if (variable_struct_exists(_current_config, "on") && variable_struct_exists(_current_config.on, _event_str)) {
                var _transition = _current_config.on[$ _event_str];
                var _can_transition = true;
                
                if (variable_struct_exists(_transition, "guard")) {
                    _can_transition = _transition.guard(context, __currentStateData, _event_data);
                }

                if (_can_transition) {
                    if (variable_struct_exists(_transition, "action")) {
                        _transition.action(context, __currentStateData, _event_data);
                    }
                    if (variable_struct_exists(_transition, "target")) {
                        __change_state(_transition.target, _event_data);
                    }
                    return; // Transition found and handled
                }
            }
        }
    }

    /// @function push(_state_id, [_event_data])
    /// @desc Pushes a new state onto the stack, pausing the current one.
    /// @param {Any} _state_id The ID of the state to push.
    /// @param {Any} [_event_data] Optional data for transition callbacks.
    push = function(_state_id, _event_data = undefined) {
        __leave_state(get_current_state(), _state_id, _event_data);
        array_push(stateStack, _state_id);
        __enter_state(get_current_state(), stateStack[array_length(stateStack)-2], _event_data);
    }
    
    /// @function pop([_event_data])
    /// @desc Pops the current state, resuming the previous state.
    /// @param {Any} [_event_data] Optional data for transition callbacks.
    pop = function(_event_data = undefined) {
        if (array_length(stateStack) <= 1) {
            __DreamState_Error("Cannot pop the base state from the FSM stack.");
            return;
        }
        var _old_top_state = get_current_state();
        __leave_state(_old_top_state, undefined, _event_data);
        array_pop(stateStack);
        __enter_state(get_current_state(), _old_top_state, _event_data);
    }

    /// @function get_current_state()
    /// @desc Gets the ID of the currently active state.
    /// @return {Any} The ID of the state at the top of the stack.
    get_current_state = function() { return stateStack[array_length(stateStack) - 1]; }
    
    /// @function get_previous_state()
    /// @desc Gets the ID of the state below the current one on the stack.
    /// @return {Any|undefined} The previous state ID, or undefined.
    get_previous_state = function() {
        var _stack_size = array_length(stateStack);
        if (_stack_size < 2) return undefined;
        return stateStack[_stack_size - 2];
    }
    
    /// @function is_state_defined(_state_id)
    /// @desc Checks if a state ID is defined in this FSM.
    /// @param {Any} _state_id The state ID to check for.
    /// @return {Bool} Returns true if the state exists.
    is_state_defined = function(_state_id) { return variable_struct_exists(processedStates, string(_state_id)); }

    /// @function is_input_active()
    /// @desc Checks if input should be processed (avoids debug UI).
    /// @return {Bool} Returns false if the debug UI is being used.
    is_input_active = function() {
        if (!DREAMSTATE_DEBUG_ENABLED) return true;
        if (is_keyboard_used_debug_overlay()) {
            return false;
        }
        var _left_click = device_mouse_check_button_pressed(0, mb_left)
        if (is_mouse_over_debug_overlay() && _left_click) {
            return false;
        }
        return true;
    }

    // --- Timer System API ---

    /// @function startTimer(_duration, _event_id, [_is_recurring=false])
    /// @desc Starts a timer that fires an event after a duration.
    /// @param {Real} _duration Duration in steps, seconds, or milliseconds.
    /// @param {Any} _event_id The event to fire when the timer ends.
    /// @param {Bool} [_is_recurring=false] If true, the timer will repeat.
    /// @return {Real} The unique ID for the new timer.
    startTimer = function(_duration, _event_id, _is_recurring = false) {
        var _time_unit = definition.config.time_unit;
        var _duration_val = 0;
        switch (_time_unit) {
            case DREAMSTATE_TIME.SECONDS:
                _duration_val = _duration * 1000000; break;
            case DREAMSTATE_TIME.MILLISECONDS:
                _duration_val = _duration * 1000;    break;
            case DREAMSTATE_TIME.STEPS:
                _duration_val = _duration;           break;
        }
        var _new_timer = { 
            id: __nextTimerId++,
            duration: _duration_val,
            remaining: _duration_val,
            event: _event_id,
            recurring: _is_recurring
        };
        array_push(__activeTimers, _new_timer);
        return _new_timer.id;
    }
    
    /// @function stopTimer(_timer_id)
    /// @desc Stops and removes an active timer.
    /// @param {Real} _timer_id The ID of the timer to stop.
    stopTimer = function(_timer_id) {
        for (var i = array_length(__activeTimers) - 1; i >= 0; i--) {
            if (__activeTimers[i].id == _timer_id) {
                array_delete(__activeTimers, i, 1);
                return;
            }
        }
    }
    
    // --- Internal ---
    
    /// @ignore
    __change_state = function(_target_id, _event_data) {
        var _old_state_id = get_current_state();
        if (_old_state_id == _target_id) return;
        
        __leave_state(_old_state_id, _target_id, _event_data);
        stateStack[array_length(stateStack)-1] = _target_id;
        __enter_state(get_current_state(), _old_state_id, _event_data);
    }
    
    /// @ignore
	__leave_state = function(_state_id, _next_state_id, _event_data) {
	    __currentStateData = undefined;
	    __log_history(_state_id);
	    __DreamState_ExecuteCallbackHierarchical(
	        self, _state_id, "onLeave", "up", self.context, 
	        _next_state_id, _event_data
	    );
	}
    
    /// @ignore
    __enter_state = function(_state_id, _previous_state_id, _event_data) {
    	var _config = processedStates[$ string(_state_id)];
	    if (variable_struct_exists(_config, "data")) {
	        // If the state has data, make a unique copy for this instance
	        __currentStateData = deep_copy(_config.data);
	    }
        var _ret = __DreamState_ExecuteCallbackHierarchical(
            self, _state_id, "onEnter", "down", self.context,
            __currentStateData, _event_data
        );
    
        // Start declarative timers from the definition
        var _config = processedStates[$ string(_state_id)];
        if (variable_struct_exists(_config, "timersOnEnter")) {
            var _timers = _config.timersOnEnter;
            for (var i = 0; i < array_length(_timers); i++) {
                var t = _timers[i];
                startTimer(t.duration, t.event, t.recurring);
            }
        }
        
        // Handle direct-return transition from onEnter
        if (_ret != undefined) {
             __change_state(_ret, _event_data);
        }
    }
    
    /// @ignore
    __get_state_name = function(_state_id) {
        if (is_string(_state_id)) return _state_id;
        
        if (definition.nameLookup != undefined) {
            var _state_id_str = string(_state_id);
            if (variable_struct_exists(definition.nameLookup, _state_id_str)) {
                return definition.nameLookup[$ _state_id_str];
            }
        }
        return string(_state_id); // Fallback
    }
    
    /// @ignore
    __log_history = function(_state_id) {
        if (!DREAMSTATE_DEBUG_ENABLED) return;
        var _history_item = {
            name: __get_state_name(_state_id),
            timestamp: current_time
        };
        array_push(self.history, _history_item);
        
        if (array_length(self.history) > DREAMSTATE_DEBUG_HISTORY_MAX_SIZE) {
            array_delete(self.history, 0, 1);
        }
    }
    
    /// @ignore
    __build_hierarchy_chain = function(_state_id) {
        var _chain = [];
        var _current_id = _state_id;
        while (is_state_defined(_current_id)) {
            var _config = processedStates[$ string(_current_id)];
            array_push(_chain, _config);
            if (variable_struct_exists(_config, "parent")) {
                _current_id = _config.parent;
            } else {
                break;
            }
        }
        return _chain;
    }
    
    // --- Timer System Internals ---
    
    /// @ignore
    __update_timers = function() {
        if (array_length(__activeTimers) == 0) return;
        
        var _time_unit = definition.config.time_unit;
        var _delta;
        switch (_time_unit) {
            case DREAMSTATE_TIME.SECONDS:      _delta = delta_time;       break;
            case DREAMSTATE_TIME.MILLISECONDS: _delta = delta_time / 1000;break;
            case DREAMSTATE_TIME.STEPS:        _delta = 1;                break;
            default:                           _delta = delta_time;       break;
        }
    
        for (var i = array_length(__activeTimers) - 1; i >= 0; i--) {
            var _timer = __activeTimers[i];
            _timer.remaining -= _delta;
            
            if (_timer.remaining <= 0) {
                fire(_timer.event, undefined, false);
                if (_timer.recurring) {
                    _timer.remaining += _timer.duration;
                } else {
                    array_delete(__activeTimers, i, 1);
                }
            }
        }
    }
}

// ======================================================================
//                              INTERNAL
// ======================================================================

/// @function __DreamStateGlobal()
/// @description 
///   (Internal) Returns a static struct holding the library's 
///   "global" state. This avoids polluting the actual global scope.
function __DreamStateGlobal() 
{
    if (_global != undefined) return _global;
    
    static _global = {
        // Cache for all FSM definitions.
        definitions: {}, 
        //.. could put other stuff here in the future?
    };
    
    show_debug_message("DreamState Library Initialized");
    
    // For convenience.
    if (DREAMSTATE_DEBUG_ENABLED) {
        global.dreamState = _global;
    }

    return _global;
}

/// @function __DreamState_ExecuteCallbackHierarchical(_fsm, _state_id, _cb_name, _dir, ...)
/// @description (Internal) Executes a callback chain using the cached hierarchy.
function __DreamState_ExecuteCallbackHierarchical(
    _fsm_instance, _state_id, _callback_name, _direction, 
    _arg1 = undefined, _arg2 = undefined, _arg3 = undefined, _arg4 = undefined) 
    {
    var _state_config = _fsm_instance.processedStates[$ string(_state_id)];
    if (!variable_struct_exists(_state_config, "__hierarchy")) return;
    
    var _hierarchy_chain = _state_config.__hierarchy;
    var _return_value = undefined;

    var _loop_array = variable_clone(_hierarchy_chain);
    if (_direction == "down") {
        array_reverse(_loop_array);
    }
    
    for (var i = 0; i < array_length(_loop_array); i++) {
        var _config = _loop_array[i];
        if (variable_struct_exists(_config, _callback_name)) {
            var _callback = _config[$ _callback_name];
            var _ret;
            try {
                if (is_struct(_config[$ _callback_name + "Info"]) && _config[$ _callback_name + "Info"].type == "fsm") {
                    _ret = _callback(_fsm_instance, _arg1, _arg2, _arg3, _arg4);
                } else { // "owner" scope is the default
                    _ret = _callback(_arg1, _arg2, _arg3, _arg4);
                }
                
                if (_ret != undefined && _return_value == undefined) {
                    _return_value = _ret;
                }
            } catch(_ex) {
				show_debug_message(_ex); 
                __DreamState_Error($"Callback error in '{_callback_name}' for state owned by [{_fsm_instance.owner}].\n{_ex.message}\n{_ex.longMessage}");
            }
        }
    }
    return _return_value;
}

/// @function __DreamState_Error(_message)
function __DreamState_Error(_message) 
{
    var _error_string = "DreamState Error: " + _message;
    if (DREAMSTATE_STRICT_MODE) {
        show_error(_error_string, true);
    } else {
        show_debug_message("DreamState Warning: " + _message);
    }
}

/// @function __DreamStateInitDebugger()
function __DreamStateInitDebugger() 
{
    if (DREAMSTATE_DEBUG_ENABLED) {
        if (!instance_exists(DREAMSTATE_DEBUGGER)) {
            if (!layer_exists(DREAMSTATE_DEBUG_LAYER)) {
                layer_create(-1000, DREAMSTATE_DEBUG_LAYER);
            }
            instance_create_layer(
                0, 0, DREAMSTATE_DEBUG_LAYER, DREAMSTATE_DEBUGGER
            );
        }
    }
}