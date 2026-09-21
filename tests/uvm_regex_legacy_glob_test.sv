// Glob callers must explicitly convert through the UVM API before matching.
// Strict regular-expression calls never retry malformed patterns as globs;
// uvm_regex_strict_exec_test separately pins that rejection contract.
`include "uvm_macros.svh"
import uvm_pkg::*;

module uvm_regex_legacy_glob_test;
  initial begin
    // Explicit conversion preserves the intended glob match and nonmatch.
    if (uvm_re_match(uvm_glob_to_re("*_shadowed"), "ctrl_shadowed") != 0)
      $fatal(1, "explicit leading-star glob did not match");
    if (uvm_re_match(uvm_glob_to_re("*_shadowed"), "ctrl") == 0)
      $fatal(1, "explicit leading-star glob matched the wrong string");

    // Valid POSIX expressions must retain normal regex behavior.
    if (uvm_re_match("^foo[0-9]+$", "foo42") != 0)
      $fatal(1, "valid POSIX regex did not match");
    if (uvm_re_match("^foo[0-9]+$", "foo") == 0)
      $fatal(1, "valid POSIX regex matched the wrong string");

    $display("PASSED: UVM strict regex and explicit glob conversion");
  end
endmodule
