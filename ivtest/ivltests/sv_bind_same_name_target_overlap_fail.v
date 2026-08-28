// IEEE 1800-2017/2023 23.11: separate directives cannot introduce the same
// bound instance name into one selected target scope.
module sv_bind_same_name_target_overlap_probe;
endmodule

module sv_bind_same_name_target_overlap_leaf;
endmodule

module sv_bind_same_name_target_overlap_fail;
  sv_bind_same_name_target_overlap_leaf target();
endmodule

bind sv_bind_same_name_target_overlap_fail.target
  sv_bind_same_name_target_overlap_probe bp();
bind sv_bind_same_name_target_overlap_fail.target
  sv_bind_same_name_target_overlap_probe bp();
