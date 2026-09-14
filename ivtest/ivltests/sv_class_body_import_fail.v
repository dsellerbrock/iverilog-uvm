// L41: an `import pkg::*;' statement written directly inside a class body
// is illegal SystemVerilog (IEEE 1800-2017/2023 A.1.8/A.2.1.3 footnote:
// "It shall be illegal to have an import statement directly within a
// class scope"), confirmed independently by Slang
// ("package import not allowed in class declaration"). Icarus already
// rejected this -- but only via bison's generic syntax-error recovery on
// the bare `import' keyword, producing a bare "syntax error" plus
// "Invalid class item.", after which recovery resynchronized and emitted
// misleading follow-on errors blaming later, unrelated lines. This is a
// real misdiagnosis found in real OpenTitan source
// (ac_range_check_env_cov.sv, pwrmgr_base_vseq.sv). Fixed to give ONE
// focused, correctly-cited diagnostic instead.
package sv_class_body_import_fail_pkg1;
  typedef int foo_t;
endpackage

module test;
  class c1;
    import sv_class_body_import_fail_pkg1::*;
    foo_t x;
  endclass
endmodule
