// IEEE 1800-2017/2023 23.11: the same fixed-point bind-under-bind rejection
// must be independent of declaration order. Here the definition binder
// appears before the installer that creates its eventual target occurrence.
module sv_bind_fixed_point_target_reversed_probe;
endmodule

module sv_bind_fixed_point_target_reversed_target;
endmodule

module sv_bind_fixed_point_target_reversed_binder;
  bind sv_bind_fixed_point_target_reversed_target
    sv_bind_fixed_point_target_reversed_probe p();
endmodule

module sv_bind_fixed_point_target_reversed_installer;
  bind sv_bind_fixed_point_target_reversed_fail
    sv_bind_fixed_point_target_reversed_target late();
endmodule

module sv_bind_fixed_point_target_reversed_fail;
  sv_bind_fixed_point_target_reversed_installer installer();
  sv_bind_fixed_point_target_reversed_binder binder();
endmodule
