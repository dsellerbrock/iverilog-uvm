// IEEE 1800-2017/2023 23.11: an absolute bind target expression declared
// inside a parameterized module is evaluated separately for every owner
// occurrence. Disjoint targets may use the same bound instance name.
package sv_bind_owner_absolute_disjoint_counts;
  int hits;
endpackage

module sv_bind_owner_absolute_disjoint_probe;
  initial sv_bind_owner_absolute_disjoint_counts::hits =
    sv_bind_owner_absolute_disjoint_counts::hits + 1;
endmodule

module sv_bind_owner_absolute_disjoint_leaf;
endmodule

module sv_bind_owner_absolute_disjoint_binder #(
  parameter int IDX = 0
);
  bind sv_bind_owner_absolute_disjoint.targets[IDX]
    sv_bind_owner_absolute_disjoint_probe bp();
endmodule

module sv_bind_owner_absolute_disjoint;
  sv_bind_owner_absolute_disjoint_leaf targets[0:1]();
  sv_bind_owner_absolute_disjoint_binder #(.IDX(0)) b0();
  sv_bind_owner_absolute_disjoint_binder #(.IDX(1)) b1();

  initial begin
    #1;
    if (sv_bind_owner_absolute_disjoint_counts::hits == 2)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_owner_absolute_disjoint_counts::hits);
  end
endmodule
