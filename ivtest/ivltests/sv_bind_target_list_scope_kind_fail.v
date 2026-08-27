// IEEE 1800-2017/2023 23.11 / Syntax 23-9: the declaration named before a
// second-form target list must be a module or interface. Program and checker
// kinds are illegal even when no elaborated occurrence matches the list.
program sv_bind_target_list_scope_kind_program;
endprogram

checker sv_bind_target_list_scope_kind_checker;
endchecker

module sv_bind_target_list_scope_kind_probe;
endmodule

bind sv_bind_target_list_scope_kind_program : missing_program
  sv_bind_target_list_scope_kind_probe from_program();

bind sv_bind_target_list_scope_kind_checker : missing_checker
  sv_bind_target_list_scope_kind_probe from_checker();

module sv_bind_target_list_scope_kind_fail;
endmodule
