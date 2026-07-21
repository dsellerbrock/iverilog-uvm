// A function whose return type is an unpacked array, assigned as a whole
// array (`r = make()`), used to abort the compiler with an internal
// assertion (store_vec4_to_lval: lwid == ivl_signal_width(lsig)) — the vvp
// calling convention has no unpacked-array return path, so the array
// result could not be delivered and code generation crashed.
//
// It must now be reported as a clean elaboration error (a graceful
// "sorry"), never a core dump. This is a CE test: vvp_reg.pl passes it
// only if ivl reports an error AND does not crash. Full support for
// unpacked-array function returns is tracked in issue #99.

module sv_uarray_func_return_fail;

  typedef int qt [3];

  function qt make();
    make = '{1, 2, 3};
  endfunction

  qt r;

  initial begin
    r = make();
    $display("%0d %0d %0d", r[0], r[1], r[2]);
    $finish(0);
  end

endmodule
