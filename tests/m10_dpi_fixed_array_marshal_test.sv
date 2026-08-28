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

  typedef int fixed_desc_result_t[10:3];
  typedef int fixed_md_result_t[2:1][4:2];

  class Item;
    int tag;
  endclass


  // Returns 0 on success or a bitmask of what was wrong.
  import "DPI-C" function int c_fixed_asc (input int a[]);
  import "DPI-C" function int c_fixed_desc(input int a[]);
  import "DPI-C" function int c_fixed_desc_ufunc(input int a[]);
  import "DPI-C" task c_fixed_desc_utask(input int a[], output int status);
  import "DPI-C" function int c_fixed_md_ufunc(input int a[][]);
  import "DPI-C" function int c_fixed_slice_ufunc(
      input int value_in[], output int value_out[], inout int value_io[]);
  import "DPI-C" function int c_dyn_plain (input int a[]);
  import "DPI-C" function void c_fixed_fill(output int unsigned a[3:10]);

  function automatic void wrap_fixed_fill(output int unsigned a[3:10]);
    c_fixed_fill(a);
  endfunction

  function automatic fixed_desc_result_t make_desc_result();
    for (int i = 10; i >= 3; i--)
      make_desc_result[i] = i * 100;
  endfunction

  function automatic fixed_md_result_t make_md_result();
    for (int i = 2; i >= 1; i--)
      for (int j = 4; j >= 2; j--)
        make_md_result[i][j] = i * 100 + j;
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
  int slice_in [0:11];
  int slice_out[11:0];
  int slice_io [0:11];

  initial begin
    foreach (asc[i])  asc[i]  = i * 100;
    foreach (desc[i]) desc[i] = i * 100;

    // 1. Fixed -> dynamic assignment (7.6). The dynamic array is 0-based,
    //    and elements correspond left-to-right.
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

    // Descending source: its left element [10] maps to dynamic element 0.
    copy = desc;
    if (copy[0] !== 1000 || copy[7] !== 300) begin
      $display("FAIL desc fixed->dynamic: copy[0]=%0d copy[7]=%0d, expected 1000 and 300",
               copy[0], copy[7]);
      errors++;
    end

    // 2. Fixed array -> DPI open array, both range directions.
    check("c_fixed_asc",  c_fixed_asc(asc));
    check("c_fixed_desc", c_fixed_desc(desc));

    // A fixed-array-valued function call is still the actual fixed array;
    // both imported DPI functions and imported DPI tasks must activate its
    // declared range and canonical numeric-low C view.
    check("c_fixed_desc_ufunc", c_fixed_desc_ufunc(make_desc_result()));
    begin
      int task_status;
      c_fixed_desc_utask(make_desc_result(), task_status);
      check("c_fixed_desc_utask", task_status);
    end
    check("c_fixed_md_ufunc", c_fixed_md_ufunc(make_md_result()));

    // A value-returning DPI import takes the nonvoid-function argument path.
    // Its fixed-array slice actuals remain open arrays with the slice's own
    // bounds. The descending output slice is deliberate: C addresses its
    // elements by numeric declared index, while native SV aggregate copy-out
    // pairs elements left-to-right. This pins the DPI-specific inverse
    // copyback and proves that only the selected storage window changes.
    foreach (slice_in[i])  slice_in[i]  = 20000 + i;
    foreach (slice_out[i]) slice_out[i] = -20000 - i;
    foreach (slice_io[i])  slice_io[i]  = 40000 + i;
    check("c_fixed_slice_ufunc",
          c_fixed_slice_ufunc(slice_in[3:6], slice_out[8:5],
                              slice_io[2:5]));
    foreach (slice_in[i]) begin
      if (slice_in[i] !== 20000 + i) begin
        $display("FAIL DPI slice input changed: slice_in[%0d]=%0d", i,
                 slice_in[i]);
        errors++;
      end
      if (i >= 5 && i <= 8) begin
        if (slice_out[i] !== 30000 + i) begin
          $display("FAIL DPI output slice copyback: slice_out[%0d]=%0d, expected %0d",
                   i, slice_out[i], 30000 + i);
          errors++;
        end
      end
      else if (slice_out[i] !== -20000 - i) begin
        $display("FAIL DPI output slice neighbor changed: slice_out[%0d]=%0d",
                 i, slice_out[i]);
        errors++;
      end
      if (i >= 2 && i <= 5) begin
        if (slice_io[i] !== 50000 + i) begin
          $display("FAIL DPI inout slice copyback: slice_io[%0d]=%0d, expected %0d",
                   i, slice_io[i], 50000 + i);
          errors++;
        end
      end
      else if (slice_io[i] !== 40000 + i) begin
        $display("FAIL DPI inout slice neighbor changed: slice_io[%0d]=%0d",
                 i, slice_io[i]);
        errors++;
      end
    end

    // 3. A real dynamic array must still report 0-based bounds -- the
    //    declared-range support must not leak into arrays that have none.
    dyn = new[5];
    foreach (dyn[i]) dyn[i] = i * 7;
    check("c_dyn_plain", c_dyn_plain(dyn));

    // 4. A fixed output formal uses the normalized direct C-array ABI (not an
    //    svOpenArrayHandle) and remains an aggregate through both the SV
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
