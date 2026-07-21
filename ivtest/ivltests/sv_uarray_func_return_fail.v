// Assignment of an unpacked-array function return to an array of a
// DIFFERENT shape must be a clean elaboration error (IEEE 1800-2017 7.6:
// unpacked-array assignment requires assignment-compatible types — equal
// element counts and compatible element types).
//
// History: `r = make()` for a MATCHING shape used to abort the compiler
// with an internal assertion (store_vec4_to_lval) because the vvp calling
// convention had no unpacked-array return path; that became a graceful
// sorry, and the feature is now implemented (issue #99 — see
// sv_uarray_func_return for the positive test). This CE test now pins the
// remaining requirement: a shape MISMATCH is diagnosed cleanly, never
// crashes, and never silently miscompiles.

module sv_uarray_func_return_fail;

  typedef int qt [3];

  function qt make();
    make = '{1, 2, 3};
  endfunction

  int r[4];  // wrong element count: 4 vs the function's 3

  initial begin
    r = make();
    $display("%0d %0d %0d", r[0], r[1], r[2]);
    $finish(0);
  end

endmodule
