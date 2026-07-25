// M10-1/R7: open-array bounds accessors (IEEE 1800-2017 H.10.1/H.10.2).
//
// Two of them returned hardcoded values that were silently wrong:
//
//   svIncrement always returned -1. H.10.2 defines it as +1 when
//   left <= right and -1 when left > right, and every array that can be
//   marshaled today is a dynamic array -- 0-based ascending -- so the
//   answer was wrong for all of them. A C model stepping an index by
//   svIncrement walked the wrong way, with no diagnostic.
//
//   svSizeOfArray computed `length * elem_bytes'. That is right for a 1-D
//   array but returns 0 for a multi-dimensional one, because the outer
//   array of a nesting is non-contiguous and so reports elem_bytes 0. A C
//   model sizing a buffer from it silently got zero.
//
// The C side returns a bitmask of failures so a wrong value is a test
// failure rather than something a human has to spot in a log. The checks
// are written against values that differ from the old hardcoded ones:
// increment must be +1, and the 2x3 int array must be 24 bytes.
//
// svLow returning 0 is correct for these arrays but only incidentally --
// dynamic arrays are 0-based. A fixed-size array with a declared range
// would need real bounds and cannot be marshaled yet (tgt-vvp says so with
// a sorry), which is tracked under M10-1.
module m10_dpi_open_array_bounds_test;

  // Each returns 0 on success, or a bitmask identifying which query was
  // wrong, so the SV side can report precisely what failed.
  import "DPI-C" function int c_bounds_1d(input int arr[]);
  import "DPI-C" function int c_bounds_2d(input int arr[][]);
  import "DPI-C" function int c_bounds_real(input real arr[]);
  import "DPI-C" function int c_walk_by_increment(input int arr[]);

  int errors = 0;

  task automatic check(input string name, input int mask);
    if (mask != 0) begin
      $display("FAIL %s: failure mask 0x%0h", name, mask);
      errors++;
    end
  endtask

  int d[];
  int md[][];
  real r[];

  initial begin
    // 1-D: 8 ints -> size 8, low 0, high 7, left 0, right 7,
    //               increment +1, sizeOfArray 32.
    d = new[8];
    foreach (d[i]) d[i] = i * 3;
    check("c_bounds_1d", c_bounds_1d(d));

    // A C loop driven by svLow/svHigh/svIncrement must visit every
    // element exactly once and in order. With increment -1 it used to
    // walk away from the array immediately.
    check("c_walk_by_increment", c_walk_by_increment(d));

    // 2-D: 2 x 3 ints -> dims 2, sizes 2 and 3, sizeOfArray 24.
    md = new[2];
    for (int i = 0; i < 2; i++) begin
      md[i] = new[3];
      for (int j = 0; j < 3; j++) md[i][j] = i * 10 + j;
    end
    check("c_bounds_2d", c_bounds_2d(md));

    // real elements: 4 doubles -> sizeOfArray 32 on any normal ABI.
    r = new[4];
    foreach (r[i]) r[i] = i + 0.5;
    check("c_bounds_real", c_bounds_real(r));

    if (errors == 0) $display("PASS m10_dpi_open_array_bounds_test");
    $finish(0);
  end

endmodule
