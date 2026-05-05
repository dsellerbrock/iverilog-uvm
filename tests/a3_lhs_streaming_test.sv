// Phase 63a / A3: LHS streaming `{<<N{x}} = rhs` is equivalent to
// `x = {<<N{rhs}}`.  Pre-fix: PEStreaming had no elaborate_lval, so
// the assignment was rejected at elaboration.
//
// UVM uvm_packer uses this pattern for byte-endian conversion.
`timescale 1ns/1ps

module top;
  initial begin
    bit [15:0] src;
    bit [15:0] dst;

    src = 16'hABCD;
    // {<<8{dst}} = src  is equivalent to dst = {<<8{src}}
    // Reverses 8-bit chunks.  src=ABCD → dst=CDAB.
    {<<8{dst}} = src;
    if (dst !== 16'hCDAB) begin
      $display("FAIL: dst=%h, expected CDAB", dst);
      $fatal(1, "A3 regression: LHS streaming did not reverse chunks");
    end

    // {<<{dst}} = src reverses ALL bits.  src=ABCD → dst=B3D5.
    // (ABCD = 1010_1011_1100_1101 → reversed = 1011_0011_1101_0101 = B3D5)
    {<<{dst}} = src;
    if (dst !== 16'hB3D5) begin
      $display("FAIL: bit-reverse dst=%h, expected B3D5", dst);
      $fatal(1, "A3 regression: LHS bit-streaming did not reverse");
    end

    $display("PASS: LHS streaming `{<<N{x}} = src` round-trips");
    $finish;
  end
endmodule
