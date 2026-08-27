// IEEE 1800-2017/2023 23.11: an absolute bind is evaluated per owner, but
// two owner occurrences selecting the same target would introduce the same
// bound instance name twice and are an error.
module sv_bind_owner_absolute_overlap_probe;
endmodule

module sv_bind_owner_absolute_overlap_leaf;
endmodule

module sv_bind_owner_absolute_overlap_binder #(
  parameter int IDX = 0
);
  bind sv_bind_owner_absolute_overlap_fail.targets[IDX]
    sv_bind_owner_absolute_overlap_probe bp();
endmodule

module sv_bind_owner_absolute_overlap_fail;
  sv_bind_owner_absolute_overlap_leaf targets[0:1]();
  sv_bind_owner_absolute_overlap_binder #(.IDX(0)) first();
  sv_bind_owner_absolute_overlap_binder #(.IDX(0)) second();
endmodule
