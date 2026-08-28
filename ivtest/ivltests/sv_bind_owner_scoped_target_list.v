// IEEE 1800-2017/2023 23.11: a selected target-instance-list entry is
// resolved in the scope containing the bind. It must not match an identically
// named instance array elsewhere in the hierarchy.
package sv_bind_owner_scoped_target_list_counts;
  int owner_hits;
  int outsider_hits;
  int errors;
endpackage

module sv_bind_owner_scoped_target_list_probe(input int observed);
  initial begin
    #0;
    case (observed)
      11: sv_bind_owner_scoped_target_list_counts::owner_hits =
            sv_bind_owner_scoped_target_list_counts::owner_hits + 1;
      22: sv_bind_owner_scoped_target_list_counts::outsider_hits =
            sv_bind_owner_scoped_target_list_counts::outsider_hits + 1;
      default: sv_bind_owner_scoped_target_list_counts::errors =
            sv_bind_owner_scoped_target_list_counts::errors + 1;
    endcase
  end
endmodule

module sv_bind_owner_scoped_target_list_leaf #(
  parameter int TAG = 0
);
endmodule

module sv_bind_owner_scoped_target_list_holder #(
  parameter int SELECTED = 1
);
  sv_bind_owner_scoped_target_list_leaf #(.TAG(11)) inst[0:1]();

  bind sv_bind_owner_scoped_target_list_leaf : inst[SELECTED]
    sv_bind_owner_scoped_target_list_probe bp(.observed(TAG));
endmodule

module sv_bind_owner_scoped_target_list_outsider;
  sv_bind_owner_scoped_target_list_leaf #(.TAG(22)) inst[0:1]();
endmodule

module sv_bind_owner_scoped_target_list;
  sv_bind_owner_scoped_target_list_holder owner();
  sv_bind_owner_scoped_target_list_outsider outsider();

  initial begin
    #1;
    if (sv_bind_owner_scoped_target_list_counts::owner_hits == 1
        && sv_bind_owner_scoped_target_list_counts::outsider_hits == 0
        && sv_bind_owner_scoped_target_list_counts::errors == 0)
      $display("PASSED");
    else
      $display("FAILED: owner=%0d outsider=%0d errors=%0d",
               sv_bind_owner_scoped_target_list_counts::owner_hits,
               sv_bind_owner_scoped_target_list_counts::outsider_hits,
               sv_bind_owner_scoped_target_list_counts::errors);
  end
endmodule
