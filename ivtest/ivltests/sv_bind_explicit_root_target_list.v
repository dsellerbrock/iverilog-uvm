// IEEE 1800-2017/2023 23.11 / Syntax 23-9: each second-form bind target
// instance is a hierarchical_identifier and therefore may start with
// $root. The local instance with the same name as the root top proves that
// the prefix forces absolute lookup rather than declaration-owner lookup.
package sv_bind_explicit_root_target_list_counts;
  int hits;
endpackage

module sv_bind_explicit_root_target_list_leaf;
endmodule

module sv_bind_explicit_root_target_list_probe;
  initial sv_bind_explicit_root_target_list_counts::hits =
    sv_bind_explicit_root_target_list_counts::hits + 1;
endmodule

module sv_bind_explicit_root_target_list_binder;
  sv_bind_explicit_root_target_list_leaf
    sv_bind_explicit_root_target_list();

  bind sv_bind_explicit_root_target_list_leaf :
    $root.sv_bind_explicit_root_target_list.left,
    $root.sv_bind_explicit_root_target_list.right
      sv_bind_explicit_root_target_list_probe bp();
endmodule

module sv_bind_explicit_root_target_list;
  sv_bind_explicit_root_target_list_leaf left();
  sv_bind_explicit_root_target_list_leaf right();
  sv_bind_explicit_root_target_list_binder owner();

  initial begin
    #1;
    if (sv_bind_explicit_root_target_list_counts::hits == 2)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_explicit_root_target_list_counts::hits);
  end
endmodule
