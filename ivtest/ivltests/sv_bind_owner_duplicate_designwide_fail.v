// IEEE 1800-2017/2023 23.11: a designwide bind declared in a module is
// elaborated once per containing-module instance. Multiple owner instances
// would introduce the same bound instance name into the target and are an
// error.
module sv_bind_owner_duplicate_designwide_probe;
endmodule

module sv_bind_owner_duplicate_designwide_leaf;
endmodule

module sv_bind_owner_duplicate_designwide_binder;
  bind sv_bind_owner_duplicate_designwide_leaf
    sv_bind_owner_duplicate_designwide_probe bp();
endmodule

module sv_bind_owner_duplicate_designwide_fail;
  sv_bind_owner_duplicate_designwide_binder first();
  sv_bind_owner_duplicate_designwide_binder second();
  sv_bind_owner_duplicate_designwide_leaf target();
endmodule
