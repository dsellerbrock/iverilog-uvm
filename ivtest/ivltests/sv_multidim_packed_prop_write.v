// M4B-10: slice / element / element+part writes into a MULTI-DIMENSIONAL
// packed vector reached as a class property or struct member (constant
// indices). Formerly a loud sorry (single-dim canonicalization only); now the
// leading bit indices map through prefix_to_slice to a canonical offset/width,
// narrowed by an optional trailing part-select. IEEE 1800-2017 7.4.
// (Variable multi-dim indices are still a loud sorry, not a miscompile.)
// Self-checking.
module sv_multidim_packed_prop_write;
  class R;
    logic [3:0][7:0] m2;      // 2-D, 32 bits
    logic [1:0][2:0][3:0] m3; // 3-D, 24 bits
  endclass
  typedef struct { logic [3:0][7:0] s; } st_t;

  int errors = 0;
  initial begin
    automatic R r = new;
    st_t s;

    // 2-D slice (element) write.
    r.m2 = 0; r.m2[1] = 8'hAB;
    if (r.m2 !== 32'h0000AB00) begin $display("FAIL m2[1]=%h exp 0000ab00", r.m2); errors++; end

    // 2-D element then part-select.
    r.m2[3][3:0] = 4'hF;
    if (r.m2 !== 32'h0F00AB00) begin $display("FAIL m2[3][3:0]=%h exp 0f00ab00", r.m2); errors++; end

    // 2-D full bit select.
    r.m2 = 0; r.m2[2][5] = 1'b1;
    if (r.m2 !== 32'h00200000) begin $display("FAIL m2[2][5]=%h exp 00200000", r.m2); errors++; end

    // 3-D slice and full bit select.
    r.m3 = 0; r.m3[1] = 12'hABC;
    if (r.m3 !== 24'hABC000) begin $display("FAIL m3[1]=%h exp abc000", r.m3); errors++; end
    r.m3 = 0; r.m3[0][2][3] = 1'b1;
    if (r.m3 !== 24'h000800) begin $display("FAIL m3[0][2][3]=%h exp 000800", r.m3); errors++; end

    // Multi-dim packed struct member, slice + part-select.
    s.s = 0; s.s[1][7:4] = 4'hD;
    if (s.s !== 32'h0000D000) begin $display("FAIL s.s[1][7:4]=%h exp 0000d000", s.s); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
