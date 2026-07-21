// IEEE 1800-2017 7.6 / 10.9.1: assignment of an assignment pattern to an
// unpacked-array SLICE — a partial index into a multi-dimensional unpacked
// array that selects a whole sub-array, e.g. `m[0] = '{1,2,3}` where m is
// int[2][3]. This used to fail elaboration with "sorry: Assignment to an
// array slice is not yet supported."
//
// The l-value now carries the flat base word of the slice plus the
// sub-array type, and the code generator stores the pattern element by
// element starting at that base. Checks: 2-D row stores land at the right
// offsets without touching other rows, a 3-D two-index slice works, real
// and string element types work, and whole-array pattern stores (already
// supported) are unaffected.

module sv_uarray_slice_pattern_assign;

  int errors = 0;

  task automatic expect_int(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %0d exp %0d", what, got, exp);
      errors++;
    end
  endtask

  int m[2][3];
  int t[2][2][2];
  real r[2][2];
  string s[2][2];

  initial begin
    // 2-D: store each row via a slice pattern; both rows land correctly.
    m[0] = '{1, 2, 3};
    m[1] = '{4, 5, 6};
    expect_int("m[0][0]", m[0][0], 1);
    expect_int("m[0][2]", m[0][2], 3);
    expect_int("m[1][0]", m[1][0], 4);
    expect_int("m[1][2]", m[1][2], 6);

    // 2-D: writing one row must not touch the other.
    m[0] = '{0, 0, 0};
    m[1] = '{0, 0, 0};
    m[1] = '{7, 8, 9};
    expect_int("m[0][1] untouched", m[0][1], 0);
    expect_int("m[1][1]", m[1][1], 8);

    // 3-D: a two-index slice selects the innermost row.
    t[1][0] = '{21, 22};
    expect_int("t[1][0][0]", t[1][0][0], 21);
    expect_int("t[1][0][1]", t[1][0][1], 22);
    expect_int("t[0][0][0] untouched", t[0][0][0], 0);

    // Real elements through a slice.
    r[1] = '{1.5, 2.5};
    if (r[1][0] != 1.5 || r[1][1] != 2.5) begin
      $display("FAIL real slice: %g %g", r[1][0], r[1][1]);
      errors++;
    end

    // String elements through a slice.
    s[0] = '{"ab", "cd"};
    if (s[0][0] != "ab" || s[0][1] != "cd") begin
      $display("FAIL string slice: %0s %0s", s[0][0], s[0][1]);
      errors++;
    end

    // Whole-array pattern store still works (regression guard).
    m = '{'{10, 11, 12}, '{13, 14, 15}};
    expect_int("whole m[0][0]", m[0][0], 10);
    expect_int("whole m[1][2]", m[1][2], 15);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
