// IEEE 1800-2017/2023 23.11: the first component of an absolute bind target
// must be an elaborated root instance, not merely the name of a module type
// that is instantiated below another root.
module sv_bind_owner_nonroot_absolute_probe;
endmodule

module sv_bind_owner_nonroot_absolute_leaf;
endmodule

module sv_bind_owner_nonroot_absolute_child;
  sv_bind_owner_nonroot_absolute_leaf u();
endmodule

module sv_bind_owner_nonroot_absolute_fail;
  sv_bind_owner_nonroot_absolute_child child_i();
endmodule

bind sv_bind_owner_nonroot_absolute_child.u
  sv_bind_owner_nonroot_absolute_probe bp();
