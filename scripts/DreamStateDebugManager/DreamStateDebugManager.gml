// DreamState
// Script: DreamStateDebugManager.gml


/// @function __DreamState_GetDebugManager()
/// @description Returns the persistent singleton struct for the debug manager.
function __DreamState_GetDebugManager() {
    static _manager = undefined;
    if (_manager != undefined) return _manager;
    
    // Initialize on first run
    _manager = {
        registered_fsms: [],
        selected_fsm: noone,
        history_dropdown_open: false,
        selected_pool_entity_pool: noone,
        selected_pool_entity_row: -1,
    };
    
    return _manager;
}

/// @function DreamStateDebugRegisterFsm(_fsm_context)
/// @description Registers the FSM instance with the Debugger. 
function DreamStateDebugRegisterFsm(_fsm_context) {
    static _manager = __DreamState_GetDebugManager();
    array_push(_manager.registered_fsms, _fsm_context);
}

/// @function DreamStateDebugUnregisterFsm(_fsm_context)
/// @description Unregisters an FSM context with the debug manager.
/// @param {Struct.DreamStateContext} _fsm_context The FSM context to register.
function DreamStateDebugUnregisterFsm(_fsm_context) {
    static _manager = __DreamState_GetDebugManager();
    var _fsms = _manager.registered_fsms;
    var _index = -1;
    var _len = array_length(_fsms);
    for (var i = 0; i < _len; i++) {
        if (_fsms[i] == _fsm_context) {
            _index = i;
            break;
        }
    }
    
    if (_index > -1) {
        array_delete(_fsms, _index, 1);
    }
}

/// @function DreamStateDebugGetSelectedFsm()
function DreamStateDebugGetSelectedFsm() {
    static _manager = __DreamState_GetDebugManager();

    // --- Garbage Collection: Remove destroyed instances ---
    var _fsms = _manager.registered_fsms;
    for (var i = array_length(_fsms) - 1; i >= 0; i--) {
        var _fsm = _fsms[i];
        if (!instance_exists(_fsm.owner)) {
            if (_manager.selected_fsm == _fsm) {
                _manager.selected_fsm = noone;
            }
            array_delete(_fsms, i, 1);
        }
    }
    
    if (_manager.selected_fsm == noone && array_length(_fsms) > 0) {
        _manager.selected_fsm = _fsms[0];
    }
    
    return _manager.selected_fsm;
}

/// @function DreamStateDebugSetSelectedPoolEntity(_pool, _row_index)
/// @description Sets the currently inspected pseudo-object.
function DreamStateDebugSetSelectedPoolEntity(_pool, _row_index) {
    static _manager = __DreamState_GetDebugManager();
    _manager.selected_pool_entity_pool = _pool;
    _manager.selected_pool_entity_row = _row_index;
}

/// @function DreamStateDebugGetSelectedPoolEntity()
/// @description Gets the currently inspected pseudo-object.
function DreamStateDebugGetSelectedPoolEntity() {
    static _manager = __DreamState_GetDebugManager();
    return {
        pool: _manager.selected_pool_entity_pool,
        row_index: _manager.selected_pool_entity_row,
    };
}

