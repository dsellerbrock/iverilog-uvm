// M10: DPI packed vector marshaling for wide (>64-bit) arguments
// (IEEE 1800-2017 35.5.6). Previously by-value DPI arguments were limited
// to 64 bits (a loud sorry); now 2-state `bit [W-1:0]` arguments marshal
// as svBitVecVal[] and 4-state `logic [W-1:0]` as svLogicVecVal[], passed
// as pointers, for input, output and inout of any width. Here W = 72
// (three 32-bit words).
module m10_dpi_wide_vector_test_top;
  import "DPI-C" function void wide_xor(input bit [71:0] a,
                                        input bit [71:0] b,
                                        output bit [71:0] c);
  import "DPI-C" function void wide_logic_copy(input  logic [71:0] a,
                                               output logic [71:0] b);
  import "DPI-C" function void wide_logic_invert(input  logic [71:0] a,
                                                 output logic [71:0] b);

  bit   [71:0] a, b, c;
  logic [71:0] la, lb;
  int errors = 0;

  initial begin
    // 2-state wide xor (svBitVecVal round trip, output copy-back).
    a = 72'hDEAD_BEEF_1234_5678_9A;
    b = 72'h0F0F_0F0F_0F0F_0F0F_0F;
    wide_xor(a, b, c);
    if (c !== (a ^ b)) begin
      $display("FAIL: wide_xor c=%h exp=%h", c, a ^ b); errors++;
    end

    // 4-state passthrough preserving X/Z (svLogicVecVal round trip).
    la = 72'h1234_5678_9ABC_DEF0_11;
    la[3]  = 1'bx;
    la[70] = 1'bz;
    wide_logic_copy(la, lb);
    if (lb !== la) begin
      $display("FAIL: wide_logic_copy lb=%h exp=%h", lb, la); errors++;
    end

    // 4-state read+write: complement known bits, keep X/Z in place.
    wide_logic_invert(la, lb);
    for (int i = 0; i < 72; i++) begin
      if (la[i] === 1'b0 && lb[i] !== 1'b1) begin
        $display("FAIL: invert bit %0d la=0 lb=%b", i, lb[i]); errors++;
      end
      if (la[i] === 1'b1 && lb[i] !== 1'b0) begin
        $display("FAIL: invert bit %0d la=1 lb=%b", i, lb[i]); errors++;
      end
      if (la[i] === 1'bx && lb[i] !== 1'bx) begin
        $display("FAIL: invert bit %0d la=x lb=%b", i, lb[i]); errors++;
      end
      if (la[i] === 1'bz && lb[i] !== 1'bz) begin
        $display("FAIL: invert bit %0d la=z lb=%b", i, lb[i]); errors++;
      end
    end

    if (errors == 0) $display("PASS: m10 dpi wide vector");
    else $display("FAIL: m10 dpi wide vector (%0d errors)", errors);
    $finish(0);
  end
endmodule
