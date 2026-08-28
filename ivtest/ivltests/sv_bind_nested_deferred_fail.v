// IEEE 1800-2017/2023 23.11: a contained bind that becomes live only after
// its owner is introduced by another bind still cannot insert an instance
// underneath that outer bind instance.
module sv_bind_nested_deferred_probe;
endmodule

module sv_bind_nested_deferred_leaf;
endmodule

module sv_bind_nested_deferred_binder;
  sv_bind_nested_deferred_leaf child();
  bind child sv_bind_nested_deferred_probe p();
endmodule

module sv_bind_nested_deferred_installer;
  bind sv_bind_nested_deferred_fail sv_bind_nested_deferred_binder b();
endmodule

module sv_bind_nested_deferred_fail;
  sv_bind_nested_deferred_installer installer();
endmodule
