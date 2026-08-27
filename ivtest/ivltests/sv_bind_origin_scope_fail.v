// IEEE 1800-2017/2023 23.11: a bind directive may be declared only in a
// module, an interface, or compilation-unit scope. Program and checker
// declarations are both invalid origins even when their target is a module.
module sv_bind_origin_scope_target;
endmodule

module sv_bind_origin_scope_probe;
endmodule

program sv_bind_origin_scope_program;
  bind sv_bind_origin_scope_target sv_bind_origin_scope_probe from_program();
endprogram

checker sv_bind_origin_scope_checker;
  bind sv_bind_origin_scope_target sv_bind_origin_scope_probe from_checker();
endchecker

module sv_bind_origin_scope_fail;
  sv_bind_origin_scope_target target();
  sv_bind_origin_scope_program program_owner();
  sv_bind_origin_scope_checker checker_owner();
endmodule
