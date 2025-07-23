var mx = device_mouse_x_to_gui(0);
var my = device_mouse_y_to_gui(0);
var nearest_dist = infinity;
var nearest_index = -1;

var _h = ds_grid_height(entity_grid);
for (var i = 0; i < _h; i++) {
    var ex = entity_grid[# obj_demo.x, i];
    var ey = entity_grid[# obj_demo.y, i];
    var dist = point_distance(mx, my, ex, ey);
    
    if (dist < nearest_dist && dist < 20) {
        nearest_dist = dist;
        nearest_index = i;
    }
}