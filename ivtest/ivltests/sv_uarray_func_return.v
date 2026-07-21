// IEEE 1800-2017 13.4: a function may return an unpacked array (via a
// typedef), and the result may be assigned to an assignment-compatible
// array or array slice. This used to abort the compiler (then, briefly, a
// graceful sorry): the vvp calling convention has no unpacked-array %ret
// path. Issue #99.
//
// Implementation: the function's return signal is emitted as a real array;
// the body stores the result elements into it and the call site invokes
// the function like a void function, then copies the words out (while the
// callee frame is still allocated) into the target array at the correct
// base offset (0 for a whole array, the slice's flat base word otherwise).
//
// Covers: automatic and static functions; int, real and string element
// types; a multi-dimensional return built with slice assignments; a
// function argument feeding the result; and an array-slice target.

module sv_uarray_func_return;

  typedef int    quad_t[4];
  typedef real   rp_t[2];
  typedef string sp_t[2];
  typedef int    m2_t[2][3];

  int errors = 0;

  task automatic expect_int(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %0d exp %0d", what, got, exp);
      errors++;
    end
  endtask

  // Automatic function, element-wise result construction, uses its arg.
  function automatic quad_t scaled(input int k);
    for (int i = 0; i < 4; i++) scaled[i] = k * (i + 1);
  endfunction

  // Static-lifetime function, pattern result.
  function rp_t makerp();
    makerp = '{1.25, 2.5};
  endfunction

  function automatic sp_t makesp();
    makesp = '{"hi", "yo"};
  endfunction

  // Multi-dimensional return, built with slice assignments.
  function automatic m2_t make2d();
    make2d[0] = '{1, 2, 3};
    make2d[1] = '{4, 5, 6};
  endfunction

  int a[4];
  real r[2];
  string s[2];
  int m[2][3];
  int mm[2][4];

  initial begin
    a = scaled(3);
    expect_int("scaled[0]", a[0], 3);
    expect_int("scaled[3]", a[3], 12);

    r = makerp();
    if (r[0] != 1.25 || r[1] != 2.5) begin
      $display("FAIL real return: %g %g", r[0], r[1]);
      errors++;
    end

    s = makesp();
    if (s[0] != "hi" || s[1] != "yo") begin
      $display("FAIL string return: %0s %0s", s[0], s[1]);
      errors++;
    end

    m = make2d();
    expect_int("2d[0][0]", m[0][0], 1);
    expect_int("2d[1][2]", m[1][2], 6);

    // Array-slice target: only row 1 is written.
    mm[0] = '{0, 0, 0, 0};
    mm[1] = scaled(2);
    expect_int("slice row0 untouched", mm[0][2], 0);
    expect_int("slice row1[0]", mm[1][0], 2);
    expect_int("slice row1[3]", mm[1][3], 8);

    // Calling the same function again with a different argument reuses
    // the return storage correctly.
    a = scaled(5);
    expect_int("re-call [3]", a[3], 20);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
