// In obj_stress_test_manager -> Draw Event
draw_primitive_begin(pr_pointlist);

for (var i = 0; i < ENTITY_COUNT; i++) {
    var _x = entity_grid[# DEMO_ENTITY.x, i];
    var _y = entity_grid[# DEMO_ENTITY.y, i];
    var _col = entity_grid[# DEMO_ENTITY.color, i];
    
    draw_vertex_color(_x, _y, _col, 1);
}

draw_primitive_end();