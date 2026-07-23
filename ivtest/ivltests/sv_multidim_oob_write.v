// M4C-6: out-of-bounds handling on multi-dimensional packed writes.
// (1) A constant OOB element write to a plain multi-dim packed variable
//     (m[7] = v where m is [3:0][7:0]) ABORTED iverilog (elab_lval.cc
//     sb_to_slice assert); it is now a warned no-op (IEEE 1800-2017
//     11.5.1/7.4.6: out-of-range select writes do not modify the target).
// (2) The same OOB form on class properties / struct members is a loud
//     sorry (M4B-10 canonicalization); ascending-range multi-dim reads and
//     writes and inner-bit OOB no-spill are locked in here too.
module sv_multidim_oob_write;
  class R; logic [0:3][7:0] m; endclass
  logic [3:0][7:0] pm;
  int errors = 0;
  initial begin
    automatic R r = new;

    pm = 32'h04030201;
    pm[2] = 8'hFF;
    if (pm !== 32'h04FF0201) begin $display("FAIL in-bounds=%h", pm); errors++; end
    pm[7] = 8'hAA;   // constant OOB element: no-op, no ICE
    if (pm !== 32'h04FF0201) begin $display("FAIL oob corrupted=%h", pm); errors++; end
    pm[1][9] = 1'b1; // inner-bit OOB: must not spill into pm[2]
    if (pm[2] !== 8'hFF) begin $display("FAIL spill=%h", pm[2]); errors++; end

    // Ascending-range multi-dim class property, read and write.
    r.m = 32'h01020304;
    if (r.m[0] !== 8'h01 || r.m[3] !== 8'h04) begin $display("FAIL asc read"); errors++; end
    r.m = 0; r.m[2] = 8'hAB;
    if (r.m !== 32'h0000AB00) begin $display("FAIL asc write=%h", r.m); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
