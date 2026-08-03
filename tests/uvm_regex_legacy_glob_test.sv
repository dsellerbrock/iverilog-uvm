// OpenTitan DV has legacy call sites which pass a glob directly to
// uvm_re_match() without setting deglob=1.  The Icarus UVM DPI bridge keeps
// normal regex semantics, but retries as a glob if POSIX rejects the original
// expression (notably a leading '*').
`include "uvm_macros.svh"
import uvm_pkg::*;

module uvm_regex_legacy_glob_test;
  initial begin
    // Invalid POSIX regex, valid OpenTitan-style glob: exercise the retry.
    if (uvm_re_match("*_shadowed", "ctrl_shadowed") != 0)
      $fatal(1, "legacy leading-star glob did not match");
    if (uvm_re_match("*_shadowed", "ctrl") == 0)
      $fatal(1, "legacy leading-star glob matched the wrong string");

    // Valid POSIX expressions must retain normal regex behavior.
    if (uvm_re_match("^foo[0-9]+$", "foo42") != 0)
      $fatal(1, "valid POSIX regex did not match");
    if (uvm_re_match("^foo[0-9]+$", "foo") == 0)
      $fatal(1, "valid POSIX regex matched the wrong string");

    $display("PASSED: UVM regex and legacy-glob compatibility");
  end
endmodule
