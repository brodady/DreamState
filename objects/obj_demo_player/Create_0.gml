// Horizontal Movement
hsp = 0;
walk_speed = 4;
acceleration = 0.5;
friction_ground = 0.2;
friction_air = 0.1;
air_control = 0.5;

// Vertical Movement
vsp = 0;
gravity_force = 0.4;
jump_force = -9;
can_wall_slide = true;
wall_slide_grace_period = false;

// Dashing
dash_speed = 10;
dash_duration_seconds = 0.2;

// Input
input_direction = 0;

// State Machine Instance
fsm = undefined;

// FSM DEFINITION
var _player_fsm_def = DreamState("PlayerFSM_Clean", function(_state) {
    
    _state.config.time_unit = DREAMSTATE_TIME.SECONDS;
	
     var _names = {};
    _names[$ PLAYER_STATE.Root]      = "Root";
    _names[$ PLAYER_STATE.Grounded]  = "Grounded";
    _names[$ PLAYER_STATE.InAir]     = "InAir";
    _names[$ PLAYER_STATE.Idle]      = "Idle";
    _names[$ PLAYER_STATE.Walk]      = "Walk";
    _names[$ PLAYER_STATE.Rising]    = "Rising";
    _names[$ PLAYER_STATE.Falling]   = "Falling";
    _names[$ PLAYER_STATE.WallSlide] = "WallSlide";
    _names[$ PLAYER_STATE.Dash]      = "Dash";
    _state.setNames(_names);
    // Check Functions 
    check_ground = function() { return place_meeting(x, y + 1, obj_wall); }
    check_wall = function(_dir) { return place_meeting(x + _dir, y, obj_wall); }
    
    // --- State Definitions ---
    
    _state.define(PLAYER_STATE.Root)
        .onEvent(PLAYER_EVENT.Dash, {
            target: PLAYER_STATE.Dash,
            guard: function() { return fsm.get_current_state() != PLAYER_STATE.Dash; }
        })
		.onEvent(PLAYER_EVENT.WallSlideCooldownEnd, {
			action: function() { can_wall_slide = true; }
		});
        
    _state.define(PLAYER_STATE.Grounded)
        .withParent(PLAYER_STATE.Root)
        .onStep(function() {
            if (!check_ground()) {
                fsm.fire(PLAYER_EVENT.Fall);
                return;
            }
            var target_hsp = input_direction * walk_speed;
            hsp = lerp(hsp, target_hsp, acceleration);
            if (input_direction == 0) {
                hsp = lerp(hsp, 0, friction_ground);
            }
            vsp = 0;
        })
        .onEvent(PLAYER_EVENT.Jump, { target: PLAYER_STATE.Rising })
        .onEvent(PLAYER_EVENT.Fall, { target: PLAYER_STATE.Falling });

    _state.define(PLAYER_STATE.Idle)
        .withParent(PLAYER_STATE.Grounded)
        .onEnter(function() { sprite_index = spr_player_idle; })
        .onEvent(PLAYER_EVENT.Move, { target: PLAYER_STATE.Walk });
        
    _state.define(PLAYER_STATE.Walk)
        .withParent(PLAYER_STATE.Grounded)
        .onEnter(function() { sprite_index = spr_player_walk; })
        .onEvent(PLAYER_EVENT.Stop, { target: PLAYER_STATE.Idle });
        
    _state.define(PLAYER_STATE.InAir)
        .withParent(PLAYER_STATE.Root)
        .onStep(function() {
            vsp += gravity_force;
            var target_hsp = input_direction * walk_speed;
            hsp = lerp(hsp, target_hsp, air_control);
            if (check_ground() && vsp >= 0) {
                fsm.fire(PLAYER_EVENT.Land);
                return;
            }
            if (check_wall(input_direction) && input_direction != 0) {
                fsm.fire(PLAYER_EVENT.HitWall);
            }
        })
        .onEvent(PLAYER_EVENT.Land, { target: PLAYER_STATE.Idle })
        .onEvent(PLAYER_EVENT.HitWall, {
            guard: function() { return vsp > 0 && can_wall_slide; },
            target: PLAYER_STATE.WallSlide
        })
        
    _state.define(PLAYER_STATE.Rising)
        .withParent(PLAYER_STATE.InAir)
        .onEnter(function() {
            sprite_index = spr_player_jump;
            vsp = jump_force;
        })
        .onStep(function() {
            if (vsp >= 0) return PLAYER_STATE.Falling;
        });
        
    _state.define(PLAYER_STATE.Falling)
        .withParent(PLAYER_STATE.InAir)
        .onEnter(function() { sprite_index = spr_player_fall; });

    _state.define(PLAYER_STATE.WallSlide)
	    .withParent(PLAYER_STATE.Root) 
	    .onEnter(function() {
	        sprite_index = spr_player_wallslide;
        
	        // Start a very short grace period timer
	        wall_slide_grace_period = true;
	        fsm.startTimer(0.1, PLAYER_EVENT.WallSlideGraceEnd); 
	    })
	    .onStep(function() {
	        vsp = min(vsp + gravity_force, 1.5);
	        hsp = 0;
        
	        if (keyboard_check_pressed(vk_space)) {
	            hsp = -image_xscale * walk_speed;
	            fsm.fire(PLAYER_EVENT.Jump);
	            return;
	        }
        
	        if (!wall_slide_grace_period) {
	            if (!check_wall(image_xscale) || input_direction == -image_xscale) {
	                fsm.fire(PLAYER_EVENT.LeaveWall);
	            } else if (check_ground()) {
	                fsm.fire(PLAYER_EVENT.Land);
	            }
	        }
	    })
	    .onEvent(PLAYER_EVENT.Jump, { target: PLAYER_STATE.Rising })
	    .onEvent(PLAYER_EVENT.Land, { target: PLAYER_STATE.Idle })
	    .onEvent(PLAYER_EVENT.LeaveWall, {
	        target: PLAYER_STATE.Falling,
	        action: function() {
	            can_wall_slide = false;
	            fsm.startTimer(0.2, PLAYER_EVENT.WallSlideCooldownEnd);
	        }
	    })
	    // Add a handler for our new event
	    .onEvent(PLAYER_EVENT.WallSlideGraceEnd, {
	        action: function() { wall_slide_grace_period = false; }
	    });
        
    _state.define(PLAYER_STATE.Dash)
        .withData({ dash_direction: 1 })
        .onEnter(function(ctx, state_data) {
            sprite_index = spr_player_dash;
            vsp = 0;
            if (input_direction != 0) {
                state_data.dash_direction = input_direction;
            } else {
                state_data.dash_direction = (image_xscale == 0) ? 1 : image_xscale;
            }
        })
        .onStep(function(ctx, state_data) {
            hsp = state_data.dash_direction * dash_speed;
        })
        .after(dash_duration_seconds, PLAYER_EVENT.DashEnd)
        .onEvent(PLAYER_EVENT.DashEnd, { target: PLAYER_STATE.Falling });
});

// Create the FSM instance (no context needed for this pattern)
fsm = _player_fsm_def.create_instance(self, PLAYER_STATE.Idle, self);