// IEEE 1800-2017/2023 23.11 / Syntax 23-9: the instance-target form names
// one instance. A final instance-array component therefore requires a
// constant element select; the array name does not expand to every element.
module sv_bind_target_unselected_array_probe;
endmodule

module sv_bind_target_unselected_array_leaf;
endmodule

module sv_bind_target_unselected_array_fail;
  sv_bind_target_unselected_array_leaf children[3:1]();
endmodule

bind sv_bind_target_unselected_array_fail.children
  sv_bind_target_unselected_array_probe bp();
