// IEEE 1800-2017/2023 23.11: duplicate entries in one target-instance list
// select the same scope twice and would introduce its bound name twice.
module sv_bind_same_name_list_overlap_probe;
endmodule

module sv_bind_same_name_list_overlap_leaf;
endmodule

module sv_bind_same_name_list_overlap_fail;
  sv_bind_same_name_list_overlap_leaf target();
endmodule

bind sv_bind_same_name_list_overlap_leaf :
  sv_bind_same_name_list_overlap_fail.target,
  sv_bind_same_name_list_overlap_fail.target
  sv_bind_same_name_list_overlap_probe bp();
