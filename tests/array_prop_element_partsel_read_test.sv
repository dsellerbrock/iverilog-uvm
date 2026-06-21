// Regression: READ a part-select / bit-select of an element of an unpacked
// ARRAY class property, e.g. `bit[63:0] a[N]` read as `a[i][31:0]` or `a[i][j]`.
//
// iverilog elaborated the trailing part-select as a second ARRAY dimension
// ("Got 2 indices, expecting 1 to index the property" / "Array cannot be
// indexed by a range"). Now the first dims.size() index components select the
// array element and any trailing components are applied as a part/bit-select on
// the (packed) element. This is the common OpenTitan scoreboard read pattern
// (e.g. intr_status_exp[i][j], compare_val[i][j][31:0]).
//
// NOTE: the l-value (write) form `a[i][31:0] = x` is a separate fix (needs a
// word-indexed property part-store opcode) and is not covered here.
module top;
  class c;
    bit [63:0] arr[4];
    bit [31:0] flat[4];
    function void init();
      arr[2] = 64'hBEEF1234_DEAD5678;
      flat[1] = 32'h0000_0008;
    endfunction
  endclass
  initial begin
    c o = new();
    int e = 0;
    bit [31:0] lo, hi;
    bit b3, b0;
    o.init();
    lo = o.arr[2][31:0];     // part-select read (const bounds)
    hi = o.arr[2][63:32];
    b3 = o.flat[1][3];       // bit-select read (const)
    b0 = o.flat[1][0];
    if (lo != 32'hDEAD5678) begin $display("FAIL lo=%h", lo); e++; end
    if (hi != 32'hBEEF1234) begin $display("FAIL hi=%h", hi); e++; end
    if (b3 != 1'b1)         begin $display("FAIL b3=%b", b3); e++; end
    if (b0 != 1'b0)         begin $display("FAIL b0=%b", b0); e++; end
    if (e == 0) $display("PASS");
    else $display("FAILED with %0d errors", e);
  end
endmodule
