// IEEE 1800-2017/2023 6.20.2 with A.2.4 -- a parameter may leave a single
// unpacked dimension UNSIZED and take its size from the initializer.
//
//     parameter string LIST_OF_LEAFS[] = { "u_daon_lc", ... };  // rstmgr_env_pkg.sv:37
//
// evaluate_range() (netmisc.cc) rejects an unsized dimension outright -- its own
// comment says such a dimension is meant to be resolved before it is called --
// and the parameter path never resolved one, so this was
// "error: An unsized dimension is not allowed here." slang 11.0.448 accepts
// every form below.
//
// Deliberately NOT inferred: a MULTI-dimensional unsized declaration. A flat
// element count says nothing about how to split the dimensions, so guessing
// would be worse than the existing loud error; that case is pinned separately
// by sv_param_unsized_multidim_fail.
//
// Also NOT addressed here, found while writing this test and still loud: a
// STRING METHOD called on an element of a string array parameter
// (`LEAFS[1].len()') is rejected with "A selected string character has byte
// type and cannot be the receiver of a string method" -- the element select is
// being read as a character select on a string. Element comparison works; only
// the method receiver form does not.

package fe_pkg;
  // brace form, as OpenTitan writes it
  parameter string LEAFS[]  = {"u_daon_lc", "u_daon_por", "u_daon_por_io"};
  // assignment-pattern form
  parameter int    VALS[]   = '{5, 6, 7, 8};
  // a sized declaration alongside, as the control
  parameter int    SIZED[3] = '{1, 2, 3};
  // replication inside the pattern still expands before the count is taken
  parameter int    REPL[]   = '{4{9}};
endpackage

module main;

  int errors = 0;

  task automatic chk(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %0s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  initial begin
    // sizes are inferred from the initializer
    chk("LEAFS size", $size(fe_pkg::LEAFS), 3);
    chk("VALS size",  $size(fe_pkg::VALS),  4);
    chk("REPL size",  $size(fe_pkg::REPL),  4);
    chk("SIZED size", $size(fe_pkg::SIZED), 3);

    // and the VALUES survive, at both ends of each array
    if (fe_pkg::LEAFS[0] != "u_daon_lc")     begin $display("FAILED: LEAFS[0]");  errors += 1; end
    if (fe_pkg::LEAFS[2] != "u_daon_por_io") begin $display("FAILED: LEAFS[2]");  errors += 1; end
    chk("VALS[0]", fe_pkg::VALS[0], 5);
    chk("VALS[3]", fe_pkg::VALS[3], 8);
    chk("REPL[0]", fe_pkg::REPL[0], 9);
    chk("REPL[3]", fe_pkg::REPL[3], 9);
    chk("SIZED[2]", fe_pkg::SIZED[2], 3);

    // Middle element, to show the inferred bounds are not just endpoints.
    if (fe_pkg::LEAFS[1] != "u_daon_por") begin $display("FAILED: LEAFS[1]"); errors += 1; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
