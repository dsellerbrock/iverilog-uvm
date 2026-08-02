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
// wrong: 3:10 (low 3, high 10, increment -1) and 10:3 (left 10, right 3,
// increment +1). $increment/svIncrement is the right-to-left increment.
// A 0-based range would hide the declared-bound translation.
module m10_dpi_fixed_array_marshal_test;

  class Item;
    int tag;
  endclass


  // Returns 0 on success or a bitmask of what was wrong.
  import "DPI-C" function int c_fixed_asc (input int a[]);
  import "DPI-C" function int c_fixed_desc(input int a[]);
  import "DPI-C" function int c_dyn_plain (input int a[]);
  import "DPI-C" function void c_fixed_fill(output int unsigned a[3:10]);

  function automatic void wrap_fixed_fill(output int unsigned a[3:10]);
    c_fixed_fill(a);
  endfunction

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

    // 4. A fixed output formal remains an aggregate through both the SV
    //    wrapper and the imported DPI function call.
    begin
      int unsigned filled[3:10];
      wrap_fixed_fill(filled);
      foreach (filled[i]) begin
        if (filled[i] !== i * 11) begin
          $display("FAIL fixed DPI output: filled[%0d]=%0d, expected %0d",
                   i, filled[i], i * 11);
          errors++;
        end
      end
    end

    // 5. A fixed array of CLASS HANDLES marshals element-wise into a
    //    dynamic array (handles copied by reference). The illegal
    //    single-handle form `h = arr' is rejected at ELABORATION, where the
    //    target type is visible -- see tests/negative/object_array_to_handle.
    //    Codegen cannot tell the two apart, so that check has to be there
    //    for this to be safe to marshal at all.
    begin
      automatic Item items[3];
      Item iq[];
      for (int i = 0; i < 3; i++) begin
        items[i] = new;
        items[i].tag = 50 + i;
      end
      iq = items;
      if (iq.size() != 3) begin
        $display("FAIL handle array size: %0d, expected 3", iq.size());
        errors++;
      end
      else if (iq[0].tag !== 50 || iq[2].tag !== 52) begin
        $display("FAIL handle array values: iq[0].tag=%0d iq[2].tag=%0d, expected 50 and 52",
                 iq[0].tag, iq[2].tag);
        errors++;
      end
      else begin
        // Handles are copied by reference, so mutating through the queue
        // must be visible through the original array.
        iq[1].tag = 999;
        if (items[1].tag !== 999) begin
          $display("FAIL handle array aliasing: items[1].tag=%0d, expected 999",
                   items[1].tag);
          errors++;
        end
      end
    end

    if (errors == 0) $display("PASS m10_dpi_fixed_array_marshal_test");
    $finish(0);
  end

endmodule
