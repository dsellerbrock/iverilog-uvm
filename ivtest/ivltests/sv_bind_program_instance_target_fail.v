// IEEE 1800-2017/2023 23.11 / Syntax 23-9: a selected program occurrence is
// not a legal bind target; only module and interface targets are permitted.
program sv_bind_program_instance_target_subject;
endprogram

module sv_bind_program_instance_target_probe;
endmodule

module sv_bind_program_instance_target_fail;
  sv_bind_program_instance_target_subject target();
endmodule

bind sv_bind_program_instance_target_fail.target
  sv_bind_program_instance_target_probe p();
