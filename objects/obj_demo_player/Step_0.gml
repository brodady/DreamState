// Step
var _left = keyboard_check(vk_left) || keyboard_check(ord("A"));
var _right = keyboard_check(vk_right) || keyboard_check(ord("D"));
var _jump_pressed = keyboard_check_pressed(vk_space);
var _dash_pressed = keyboard_check_pressed(vk_shift);

input_direction = _right - _left;


if (input_direction != 0) {
    fsm.fire(PLAYER_EVENT.Move);
} else {
    fsm.fire(PLAYER_EVENT.Stop);
}

if (_jump_pressed) {
    fsm.fire(PLAYER_EVENT.Jump);
}

if (_dash_pressed) {
    fsm.fire(PLAYER_EVENT.Dash);
}

fsm.update();

// Horizontal Collision
if (place_meeting(x + hsp, y, obj_wall))
{
    // Move as close to the wall as possible
    while (!place_meeting(x + sign(hsp), y, obj_wall))
    {
        x += sign(hsp);
    }
    hsp = 0;
}
x += hsp;

// Vertical Collision
if (place_meeting(x, y + vsp, obj_wall))
{
    // Move as close to the floor/ceiling as possible
    while (!place_meeting(x, y + sign(vsp), obj_wall))
    {
        y += sign(vsp);
    }
    vsp = 0;
}
y += vsp;


// Flip sprite based on horizontal speed
if (hsp != 0)
{
    image_xscale *= sign(hsp);
}