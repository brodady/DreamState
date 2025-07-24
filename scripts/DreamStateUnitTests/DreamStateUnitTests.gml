// Filename: ds_unit_tests.gml (Corrected v2)
// Description: Unit tests for the DreamState Hierarchical State Machine library.
// Correction: Uses 'static' structs to create test harnesses, solving GML's
// anonymous function scoping rules.

//#macro DREAMSTATE_STRICT_MODE true
#macro DREAMSTATE_DEBUG_ENABLED false // Disable debug UI for automated testing
//#macro DREAMSTATE_TIME { STEPS: 0, SECONDS: 1, MILLISECONDS: 2 }

// ======================================================================
// TEST RUNNER & ASSERTION HELPERS (Unchanged)
// ======================================================================

global.ds_test_results = {
    passed: 0,
    failed: 0,
    current_test: "None"
};

/// @function assert_equal(value, expected, message)
function assert_equal(_val, _exp, _msg = "") {
    if (_val == _exp) {
        global.ds_test_results.passed++;
    } else {
        global.ds_test_results.failed++;
        var _error = $"'{global.ds_test_results.current_test}': FAILED. {_msg}";
        var _details = $"  Expected: {string(_exp)}\n  Got: {string(_val)}";
        show_debug_message(_error + "\n" + _details);
    }
}

/// @function assert_true(value, message)
function assert_true(_val, _msg = "") {
    assert_equal(_val, true, _msg);
}

/// @function assert_false(value, message)
function assert_false(_val, _msg = "") {
    assert_equal(_val, false, _msg);
}

/// @function assert_array_equal(arr1, arr2, message)
function assert_array_equal(_arr1, _arr2, _msg = "") {
    if (!is_array(_arr1) || !is_array(_arr2) || array_length(_arr1) != array_length(_arr2)) {
        assert_equal(string(_arr1), string(_arr2), _msg);
        return;
    }
    for (var i = 0; i < array_length(_arr1); i++) {
        if (_arr1[i] != _arr2[i]) {
            assert_equal(string(_arr1), string(_arr2), _msg);
            return;
        }
    }
    assert_true(true, _msg);
}

/// @function ds_test_run_all()
function ds_test_run_all() {
    show_debug_message("===== Running DreamState Unit Tests =====");
    
    __DreamStateGlobal().definitions = {};

    ds_test_core_functionality();
    ds_test_hierarchical_behavior();
    ds_test_transitions_and_events();
    ds_test_state_stack();
    ds_test_timer_system();
    ds_test_state_data();
    ds_test_callback_scopes();

    show_debug_message("===== Test Run Complete =====");
    show_debug_message($"PASSED: {global.ds_test_results.passed}, FAILED: {global.ds_test_results.failed}");
    show_debug_message("=============================");
}

// ======================================================================
// TEST IMPLEMENTATIONS (Corrected with `static`)
// ======================================================================

/// @function ds_test_core_functionality()
function ds_test_core_functionality() {
    global.ds_test_results.current_test = "Core: Definition Caching";
    var def1 = DreamState("CoreTest", function(fsm) {});
    var def2 = DreamState("CoreTest", function(fsm) {});
    assert_true(def1 == def2, "Same definition ID should return cached definition.");
    
    global.ds_test_results.current_test = "Core: Instance Creation";
    static harness_core = {
        enter_called: false,
        on_enter_cb: function() { self.enter_called = true; }
    };
    harness_core.enter_called = false; // Reset for test run
    
    enum E_CORE_STATE { INITIAL }
    var def = DreamState("CoreTestInstance", function(fsm) {
        fsm.define(E_CORE_STATE.INITIAL).onEnter(harness_core.on_enter_cb);
    });
    
    var fsm = def.create_instance(harness_core, E_CORE_STATE.INITIAL, { score: 100 });
    
    assert_true(fsm != undefined, "FSM instance should be created successfully.");
    assert_true(harness_core.enter_called, "onEnter of initial state should be called on creation.");
}

/// @function ds_test_hierarchical_behavior()
function ds_test_hierarchical_behavior() {
    global.ds_test_results.current_test = "Hierarchy: Callback Order";
    
    static harness_hier = {
        log: [],
        parent_enter: function() { array_push(self.log, "parent_enter"); },
        child_enter:  function() { array_push(self.log, "child_enter"); },
        parent_step:  function() { array_push(self.log, "parent_step"); },
        child_step:   function() { array_push(self.log, "child_step"); },
        parent_leave: function() { array_push(self.log, "parent_leave"); },
        child_leave:  function() { array_push(self.log, "child_leave"); },
    };
    harness_hier.log = []; // Reset for test run
    
    enum E_HIER_STATE { PARENT, CHILD, OTHER }
    var def = DreamState("HierarchyTest", function(fsm) {
        fsm.define(E_HIER_STATE.PARENT).onEnter(harness_hier.parent_enter).onStep(harness_hier.parent_step).onLeave(harness_hier.parent_leave);
        fsm.define(E_HIER_STATE.CHILD).withParent(E_HIER_STATE.PARENT).onEnter(harness_hier.child_enter).onStep(harness_hier.child_step).onLeave(harness_hier.child_leave).onEvent("GOTO_OTHER", { target: E_HIER_STATE.OTHER });
        fsm.define(E_HIER_STATE.OTHER);
    });
    
    var fsm = def.create_instance(harness_hier, E_HIER_STATE.CHILD);
    assert_array_equal(harness_hier.log, ["parent_enter", "child_enter"], "onEnter should fire parent-first (down).");
}

/// @function ds_test_transitions_and_events()
function ds_test_transitions_and_events() {
    global.ds_test_results.current_test = "Transitions: Basic Event";
    static harness_trans = {
        action_fired: false,
        action_data: undefined,
        action_cb: function(ctx, st_data, ev_data) {
            self.action_fired = true;
            self.action_data = ev_data;
        }
    };
    harness_trans.action_fired = false;
    harness_trans.action_data = undefined;
    
    enum E_TRANS_STATE { A, B }
    enum E_TRANS_EVENT { GO_B }
    
    var def = DreamState("TransitionTest", function(fsm) {
        fsm.define(E_TRANS_STATE.A).onEvent(E_TRANS_EVENT.GO_B, { target: E_TRANS_STATE.B, action: harness_trans.action_cb });
        fsm.define(E_TRANS_STATE.B);
    });
    
    var fsm = def.create_instance(harness_trans, E_TRANS_STATE.A);
    fsm.fire(E_TRANS_EVENT.GO_B, { value: 42 });
    assert_equal(fsm.get_current_state(), E_TRANS_STATE.B, "FSM should transition to the target state.");
    assert_true(harness_trans.action_fired, "Transition action should be executed.");
    
    global.ds_test_results.current_test = "Transitions: Guards";
    static guard_harness = {
        allow_transition: false,
        guard_cb: function() { return self.allow_transition; }
    };
    guard_harness.allow_transition = false;
    
    def = DreamState("GuardTest", function(fsm) {
        fsm.define(E_TRANS_STATE.A).onEvent(E_TRANS_EVENT.GO_B, { target: E_TRANS_STATE.B, guard: guard_harness.guard_cb });
        fsm.define(E_TRANS_STATE.B);
    });
    
    fsm = def.create_instance(guard_harness, E_TRANS_STATE.A);
    fsm.fire(E_TRANS_EVENT.GO_B);
    assert_equal(fsm.get_current_state(), E_TRANS_STATE.A, "Transition should be blocked by a false guard.");
}

/// @function ds_test_state_stack()
function ds_test_state_stack() {
    global.ds_test_results.current_test = "Stack: Push/Pop";
    static harness_stack = {
        log: [],
        base_leave:   function() { array_push(self.log, "base_leave"); },
        paused_enter: function() { array_push(self.log, "paused_enter"); },
        paused_leave: function() { array_push(self.log, "paused_leave"); },
        base_enter:   function() { array_push(self.log, "base_enter"); },
    };
    harness_stack.log = [];
    
    enum E_STACK_STATE { BASE, PAUSED }
    var def = DreamState("StackTest", function(fsm) {
        fsm.define(E_STACK_STATE.BASE).onEnter(harness_stack.base_enter).onLeave(harness_stack.base_leave);
        fsm.define(E_STACK_STATE.PAUSED).onEnter(harness_stack.paused_enter).onLeave(harness_stack.paused_leave);
    });

    var fsm = def.create_instance(harness_stack, E_STACK_STATE.BASE);
    harness_stack.log = []; 
    
    fsm.push(E_STACK_STATE.PAUSED);
    assert_array_equal(harness_stack.log, ["base_leave", "paused_enter"], "push should call leave on old state and enter on new state.");
}

/// @function ds_test_timer_system()
function ds_test_timer_system() {
    global.ds_test_results.current_test = "Timers: Declarative 'after'";
    
    enum E_TIMER_STATE { START, END }
    enum E_TIMER_EVENT { TIMES_UP }
    
    var def = DreamState("AfterTimerTest", function(fsm) {
        fsm.config.time_unit = DREAMSTATE_TIME.STEPS;
        fsm.define(E_TIMER_STATE.START).after(5, E_TIMER_EVENT.TIMES_UP).onEvent(E_TIMER_EVENT.TIMES_UP, { target: E_TIMER_STATE.END });
        fsm.define(E_TIMER_STATE.END);
    });
    
    var fsm = def.create_instance({}, E_TIMER_STATE.START);
    for (var i = 0; i < 5; i++) fsm.update();
    assert_equal(fsm.get_current_state(), E_TIMER_STATE.END, "State should change after timer fires.");
}

/// @function ds_test_state_data()
function ds_test_state_data() {
    global.ds_test_results.current_test = "State Data: Deep Copy";
    static harness_data = {
        enter_data: undefined,
        step_data: undefined,
        capture_enter_data: function(ctx, st_data) { self.enter_data = st_data; },
        capture_step_data:  function(ctx, st_data) { self.step_data = st_data; }
    };
    harness_data.enter_data = undefined;
    harness_data.step_data = undefined;
    
    enum E_DATA_STATE { IDLE }
    var def = DreamState("DataTest", function(fsm) {
        fsm.define(E_DATA_STATE.IDLE).withData({ counter: 0 }).onEnter(harness_data.capture_enter_data).onStep(harness_data.capture_step_data);
    });
    
    var fsm1 = def.create_instance(harness_data, E_DATA_STATE.IDLE);
    harness_data.enter_data.counter = 10;
    fsm1.update();
    assert_equal(harness_data.step_data.counter, 10, "Modified state data should persist for the instance.");
    
    var fsm2 = def.create_instance(harness_data, E_DATA_STATE.IDLE);
    assert_equal(harness_data.enter_data.counter, 0, "New FSM instance should have a fresh copy of state data.");
}

/// @function ds_test_callback_scopes()
function ds_test_callback_scopes() {
    global.ds_test_results.current_test = "Scopes: on...InOwner";
    static harness_owner = { 
        scope_check: undefined,
        check_scope: function() { self.scope_check = self; }
    };
    harness_owner.scope_check = undefined;
    
    enum E_SCOPE_STATE { TEST }
    var def = DreamState("ScopeTestOwner", function(fsm) {
        fsm.define(E_SCOPE_STATE.TEST).onEnterInOwner(harness_owner.check_scope);
    });
    
    var fsm = def.create_instance(harness_owner, E_SCOPE_STATE.TEST);
    assert_equal(harness_owner.scope_check, harness_owner, "onEnterInOwner should execute with the owner as the scope.");
    
    global.ds_test_results.current_test = "Scopes: on...InFSM";
    static harness_fsm_scope = {
        scope_check: undefined,
        check_scope: function(fsm_inst) { self.scope_check = fsm_inst; }
    };
    harness_fsm_scope.scope_check = undefined;
    
    def = DreamState("ScopeTestFSM", function(fsm_def) {
        fsm_def.define(E_SCOPE_STATE.TEST).onEnterInFSM(harness_fsm_scope.check_scope);
    });
    
    fsm = def.create_instance(harness_fsm_scope, E_SCOPE_STATE.TEST);
    assert_equal(harness_fsm_scope.scope_check, fsm, "onEnterInFSM should execute with the FSM instance as its first argument.");
}