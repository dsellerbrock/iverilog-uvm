// IEEE 1800-2017/2023 23.11 / Syntax 23-9: the bind target is restricted to
// a module/interface declaration or module/interface instance. A checker can
// be the bound instantiation, but a checker declaration cannot be the target.
checker sv_bind_checker_target_subject;
endchecker

module sv_bind_checker_target_probe;
endmodule

bind sv_bind_checker_target_subject sv_bind_checker_target_probe p();

module sv_bind_checker_target_fail;
  sv_bind_checker_target_subject target();
endmodule
