// IEEE 1800-2017/2023 23.11: fixed-point bind activation must reject a
// definition bind whose target occurrence was itself created by another
// bind. The installer appears before the definition binder in source order.
module sv_bind_fixed_point_target_first_probe;
endmodule

module sv_bind_fixed_point_target_first_target;
endmodule

module sv_bind_fixed_point_target_first_installer;
  bind sv_bind_fixed_point_target_first_fail
    sv_bind_fixed_point_target_first_target late();
endmodule

module sv_bind_fixed_point_target_first_binder;
  bind sv_bind_fixed_point_target_first_target
    sv_bind_fixed_point_target_first_probe p();
endmodule

module sv_bind_fixed_point_target_first_fail;
  sv_bind_fixed_point_target_first_installer installer();
  sv_bind_fixed_point_target_first_binder binder();
endmodule
