// IEEE 1800-2017/2023 23.11: an active module-contained definition bind
// participates in the target definition's namespace. Its bound name must
// collide with a pre-existing instance even though activation is deferred
// until the containing module has an elaborated occurrence.
module sv_bind_owner_definition_collision_probe;
endmodule

module sv_bind_owner_definition_collision_leaf;
  sv_bind_owner_definition_collision_probe p();
endmodule

module sv_bind_owner_definition_collision_binder;
  bind sv_bind_owner_definition_collision_leaf
    sv_bind_owner_definition_collision_probe p();
endmodule

module sv_bind_owner_definition_collision_fail;
  sv_bind_owner_definition_collision_leaf target();
  sv_bind_owner_definition_collision_binder live_owner();
endmodule
