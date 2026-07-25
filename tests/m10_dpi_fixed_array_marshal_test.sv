// M10-1: marshal a WHOLE fixed-size unpacked array where an object is
// wanted, and report its DECLARED range through the open-array accessors.
//
// A fixed array is not an object, so both of these need a dynamic-array
// copy of its words:
//     int a[3:10]; int d[];  d = a;                    // IEEE 1800-2017 7.6
//     import "DPI-C" function void f(input int x[]); f(a);  // 35.5.6.1
// tgt-vvp used to push element 0 instead, so both silently produced an
// EMPTY array (a C model saw size 0); then it was a loud sorry.
//
// The declared range has to survive the copy. H.10.2 says the bounds
// accessors report the ACTUAL argument's dimension, not the 0..N-1 of the
// dynamic array it becomes, and H.10.3 says element access uses the
// declared index. Those two must agree, or a C model looping
//     for (i = svLow; i <= svHigh; i++) svGetArrElemPtr1(h, i)
// reads the wrong elements and runs off the end.
//
// The ranges below are chosen so every previously-hardcoded answer is
// wrong: 3:10 (low 3, high 10, increment +1) and 10:3 (left 10, right 3,
// increment -1). A 0-based range would hide all of it.
module m10_dpi_fixed_array_marshal_test;

  // Returns 0 on success or a bitmask of what was wrong.
  import "DPI-C" function int c_fixed_asc (input int a[]);
  import "DPI-C" function int c_fixed_desc(input int a[]);
  import "DPI-C" function int c_dyn_plain (input int a[]);

  int errors = 0;

  task automatic check(input string name, input int mask);
    if (mask != 0) begin
      $display("FAIL %s: failure mask 0x%0h", name, mask);
      errors++;
    end
  endtask

  int asc [3:10];      // ascending, non-zero based
  int desc[10:3];      // descending
  int dyn[];           // ordinary dynamic array: really is 0-based
  int copy[];

  initial begin
    foreach (asc[i])  asc[i]  = i * 100;
    foreach (desc[i]) desc[i] = i * 100;

    // 1. Fixed -> dynamic assignment (7.6). The dynamic array is 0-based,
    //    so element 0 is the LOW end of the source range.
    copy = asc;
    if (copy.size() != 8) begin
      $display("FAIL fixed->dynamic size: %0d, expected 8", copy.size());
      errors++;
    end
    if (copy[0] !== 300 || copy[7] !== 1000) begin
      $display("FAIL fixed->dynamic values: copy[0]=%0d copy[7]=%0d, expected 300 and 1000",
               copy[0], copy[7]);
      errors++;
    end

    // Descending source: canonically ascending by declared index, so
    // element 0 is still the low end.
    copy = desc;
    if (copy[0] !== 300 || copy[7] !== 1000) begin
      $display("FAIL desc fixed->dynamic: copy[0]=%0d copy[7]=%0d, expected 300 and 1000",
               copy[0], copy[7]);
      errors++;
    end

    // 2. Fixed array -> DPI open array, both range directions.
    check("c_fixed_asc",  c_fixed_asc(asc));
    check("c_fixed_desc", c_fixed_desc(desc));

    // 3. A real dynamic array must still report 0-based bounds -- the
    //    declared-range support must not leak into arrays that have none.
    dyn = new[5];
    foreach (dyn[i]) dyn[i] = i * 7;
    check("c_dyn_plain", c_dyn_plain(dyn));

    if (errors == 0) $display("PASS m10_dpi_fixed_array_marshal_test");
    $finish(0);
  end

endmodule
