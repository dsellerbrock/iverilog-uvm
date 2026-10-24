// IEEE 1800-2017 H.10.2/H.10.3: an open-array formal reports the DECLARED
// range of the fixed-size actual it was marshaled from, and element access
// uses that declared index.
//
// Focused reducer for the destination-copy hazard. %store/obj/open activates
// the declared-index view on the object it is about to store, but a
// destination signal that carries a declared container layout receives the
// container BY COPY, and the activation flag is deliberately not carried onto
// a value copy (an ordinary fixed-to-dynamic assignment is 0-based, 7.5).
// Once the DPI formal's temporary gained a layout, the activation landed on
// the source handle while the formal read the destination's private copy, so
// every bound accessor fell back to 0..N-1:
//
//     svLeft=0 svRight=7 svLow=0 svHigh=7      (want 3, 10, 3, 10)
//
// The size, byte count and dimension count stayed correct throughout, which
// is what made this look like a range-reporting bug rather than a marshaling
// one. Both range directions are covered because the increment sign is
// derived from left/right.
module m10_dpi_open_array_layout_range_test;

  import "DPI-C" function int c_layout_range_asc (input int a[]);
  import "DPI-C" function int c_layout_range_desc(input int a[]);

  int asc [3:10];
  int desc[10:3];
  int errors = 0;

  task automatic check(input string name, input int mask);
    if (mask != 0) begin
      $display("FAIL %s: mask 0x%0h", name, mask);
      errors++;
    end
  endtask

  initial begin
    foreach (asc[i])  asc[i]  = i * 100;
    foreach (desc[i]) desc[i] = i * 100;

    check("ascending  3:10", c_layout_range_asc(asc));
    check("descending 10:3", c_layout_range_desc(desc));

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d range checks", errors);
  end

endmodule
