// IEEE 1800-2017/2023 23.11/3.13: two bound instance arrays with the same
// base identifier collide in the target module namespace even when their
// declared index ranges are disjoint.
module sv_bind_same_base_array_collision_probe;
endmodule

module sv_bind_same_base_array_collision_leaf;
endmodule

module sv_bind_same_base_array_collision_fail;
  sv_bind_same_base_array_collision_leaf target();
endmodule

bind sv_bind_same_base_array_collision_fail.target
  sv_bind_same_base_array_collision_probe p[1:0]();
bind sv_bind_same_base_array_collision_fail.target
  sv_bind_same_base_array_collision_probe p[3:2]();
