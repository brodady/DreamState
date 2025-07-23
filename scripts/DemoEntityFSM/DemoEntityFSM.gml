enum DEMO_ENTITY {
    x,
    y,
    hsp,
    vsp,
    color,
    state,
    timer,
    COUNT 
}

enum DEMO_STATE {
    Wander,
    Wait
}

enum DEMO_EVENT {
    TimerEnd
}

function State_Wait_onEnter(_grid, _row) {
    _grid[# DEMO_ENTITY.hsp, _row] = 0;
    _grid[# DEMO_ENTITY.vsp, _row] = 0;
    _grid[# DEMO_ENTITY.timer, _row] = random_range(30, 120);
}
function State_Wait_onStep(_grid, _row, _fsm_pool) {
	//gml_pragma("forceinline");
    var _timer = _grid[# DEMO_ENTITY.timer, _row];
    _grid[# DEMO_ENTITY.timer, _row] = _timer - 1;

    if (_timer <= 0) {
        // FIX: Use the passed-in _fsm_pool variable
        _fsm_pool.fire_event(_row, DEMO_EVENT.TimerEnd);
    }
}
function State_Wander_onEnter(_grid, _row) {
    var _dir = random(360);
    var _spd = random_range(0.5, 2);
    _grid[# DEMO_ENTITY.hsp, _row] = lengthdir_x(_spd, _dir);
    _grid[# DEMO_ENTITY.vsp, _row] = lengthdir_y(_spd, _dir);
    _grid[# DEMO_ENTITY.timer, _row] = random_range(60, 180);
}
function State_Wander_onStep(_grid, _row, _fsm_pool) {
	//gml_pragma("forceinline");
    _grid[# DEMO_ENTITY.x, _row] += _grid[# DEMO_ENTITY.hsp, _row];
    _grid[# DEMO_ENTITY.y, _row] += _grid[# DEMO_ENTITY.vsp, _row];

    var _timer = _grid[# DEMO_ENTITY.timer, _row];
    _grid[# DEMO_ENTITY.timer, _row] = _timer - 1;

    if (_timer <= 0) {
        _fsm_pool.fire_event(_row, DEMO_EVENT.TimerEnd);
    }
}
function DemoEntityFSM() {
    return DreamState("DemoEntityFSM", function(_def) {
    
        _def.define(DEMO_STATE.Wait)
            .onEnter(State_Wait_onEnter)
            .onStep(State_Wait_onStep)
            .onEvent(DEMO_EVENT.TimerEnd, { target: DEMO_STATE.Wander });

        _def.define(DEMO_STATE.Wander)
            .onEnter(State_Wander_onEnter)
            .onStep(State_Wander_onStep)
            .onEvent(DEMO_EVENT.TimerEnd, { target: DEMO_STATE.Wait });
    });
}