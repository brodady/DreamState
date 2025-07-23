ENTITY_COUNT = 10000;
randomize();

entity_grid = ds_grid_create(DEMO_ENTITY.COUNT, ENTITY_COUNT);

var _room_w = room_width;
var _room_h = room_height;

for (var i = 0; i < ENTITY_COUNT; i++) {
    entity_grid[# DEMO_ENTITY.x, i] = random(_room_w);
    entity_grid[# DEMO_ENTITY.y, i] = random(_room_h);
    entity_grid[# DEMO_ENTITY.hsp, i] = 0;
    entity_grid[# DEMO_ENTITY.vsp, i] = 0;
    entity_grid[# DEMO_ENTITY.color, i] = make_color_hsv(random(255), 150, 255);
    entity_grid[# DEMO_ENTITY.state, i] = DEMO_STATE.Wait;
    entity_grid[# DEMO_ENTITY.timer, i] = random_range(30, 120);
}

// Create the FSM Pool Controller
fsm_pool = new DreamPool(DemoEntityFSM(), entity_grid, DEMO_ENTITY.state);