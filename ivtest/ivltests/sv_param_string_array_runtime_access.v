// IEEE 1800-2017/2023 6.20.2 with 7.11 and 20.7.
//
// Runtime access to a string ARRAY parameter. OpenTitan's
// rstmgr_leaf_rst_cnsty_vseq.sv:49-50 writes exactly this:
//
//   for (int i = 0; i < LIST_OF_LEAFS.size(); ++i)
//     string leaf_path = {"tb.dut.", LIST_OF_LEAFS[i], ".gen_rst_chk.u_rst_chk"};
//
// Both halves used to fail, for the SAME underlying reason: an array
// parameter's declared type is its ELEMENT type, so the array's own
// operations were dispatched against an element.
//
//   LEAFS.size()  -> sorry: the `size' method needs a value that is a
//                    constant string at elaboration
//   LEAFS[i]      -> sorry: Variable index into array parameter `LEAFS'
//                    requires integral elements
//
// The second is a genuine lowering gap: the variable-index path packs the
// whole array into one wide vector and bit-selects it, which needs integral
// equal-width elements. A CONSTANT index always worked, through a different
// path -- which is why `LEAFS[1]' compared fine while `LEAFS[i]' did not.
//
// slang 11.0.448 accepts this file under --std 1800-2017 and 1800-2023.
//
// Known limitation, deliberately still loud and NOT covered here: a string
// METHOD on an element (`LEAFS[0].len()') is rejected, because resolving the
// indexed element's constant value in the method path is separate work.

package p;
  parameter string LEAFS[] = {"u_daon_lc", "u_daon_por", "u_daon_por_io"};
  parameter string ONE[]   = {"solo"};
  parameter int    NUMS[]  = {5, 6, 7, 8};
  parameter string DESC[2] = {"sized", "array"};
endpackage

module main;
  import p::*;

  int errors = 0;

  task automatic chk(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  initial begin
    // .size() on the array itself, for string AND integral elements, and for
    // a sized declaration as well as an inferred one.
    chk("LEAFS.size", LEAFS.size(), 3);
    chk("ONE.size",   ONE.size(),   1);
    chk("NUMS.size",  NUMS.size(),  4);
    chk("DESC.size",  DESC.size(),  2);

    // The OpenTitan shape: a variable index inside a concatenation, bounded
    // by .size(). Values are checked, not merely compilation.
    for (int i = 0; i < LEAFS.size(); ++i) begin
      automatic string path = {"tb.dut.", LEAFS[i], ".chk"};
      case (i)
        0: if (path != "tb.dut.u_daon_lc.chk")
             begin $display("FAILED: path[0] = %s", path); errors += 1; end
        1: if (path != "tb.dut.u_daon_por.chk")
             begin $display("FAILED: path[1] = %s", path); errors += 1; end
        2: if (path != "tb.dut.u_daon_por_io.chk")
             begin $display("FAILED: path[2] = %s", path); errors += 1; end
      endcase
    end

    // A single-element array exercises the degenerate chain.
    for (int i = 0; i < ONE.size(); ++i)
      if (ONE[i] != "solo") begin $display("FAILED: ONE[%0d]", i); errors += 1; end

    // Integral arrays must still take the original packed-table lowering.
    for (int i = 0; i < NUMS.size(); ++i)
      chk("NUMS elem", NUMS[i], 5 + i);

    // A constant index is a different path and must be unchanged.
    if (LEAFS[1] != "u_daon_por") begin $display("FAILED: const index"); errors += 1; end
    if (DESC[0] != "sized")       begin $display("FAILED: sized const index"); errors += 1; end

    // A variable index into a SIZED string array, not just an inferred one.
    for (int i = 0; i < 2; ++i) begin
      if (i == 0 && DESC[i] != "sized") begin $display("FAILED: DESC[0] var"); errors += 1; end
      if (i == 1 && DESC[i] != "array") begin $display("FAILED: DESC[1] var"); errors += 1; end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
