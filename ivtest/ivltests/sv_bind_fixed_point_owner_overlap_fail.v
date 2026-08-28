// IEEE 1800-2017/2023 23.11: bind activation is a fixed-point operation.
// A newly bound owner occurrence must participate in duplicate-target
// checking against an ordinary occurrence of the same owner definition.
module sv_bind_fixed_point_owner_overlap_probe;
endmodule

module sv_bind_fixed_point_owner_overlap_leaf;
endmodule

module sv_bind_fixed_point_owner_overlap_binder;
  bind sv_bind_fixed_point_owner_overlap_fail.target
    sv_bind_fixed_point_owner_overlap_probe p();
endmodule

module sv_bind_fixed_point_owner_overlap_installer;
  bind sv_bind_fixed_point_owner_overlap_fail
    sv_bind_fixed_point_owner_overlap_binder extra();
endmodule

module sv_bind_fixed_point_owner_overlap_fail;
  sv_bind_fixed_point_owner_overlap_leaf target();
  sv_bind_fixed_point_owner_overlap_binder normal();
  sv_bind_fixed_point_owner_overlap_installer installer();
endmodule
