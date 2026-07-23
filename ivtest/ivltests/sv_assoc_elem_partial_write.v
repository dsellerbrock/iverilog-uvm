// M4C-9: partial writes into ASSOCIATIVE-array elements. Formerly:
// (1) a member write into an assoc element of PACKED-struct type
//     (pm[key].a = v) ABORTED iverilog (elab_lval.cc dimension assert);
// (2) a bit/part write to a vec4 assoc element (am[key][m:l] = v) was
//     silently dropped (misrouted to the integer-indexed darray path:
//     "cannot write to an undefined darray");
// (3) [base +: w]/[base -: w] on darray/queue/assoc elements was a sorry;
// (4) the %aa/loadk/v/* keep-key element load peeked the receiver at the
//     wrong object-stack depth (latent crash for vec4-keyed compound and
//     RMW forms).
// Now: elaboration lowers member writes to the member's bit range and
// indexed part-selects to canonical offsets; codegen RMWs assoc elements
// via %aa/loadk + the new %setbits/vec4[/x] + %aa/store. IEEE 1800-2017
// 7.8, 7.2.1, 11.5.1. Self-checking.
module sv_assoc_elem_partial_write;
  typedef struct packed { logic [7:0] a, b; } p_t;
  p_t pm[string];
  p_t pi[int];
  logic [15:0] am[string];
  logic [15:0] q[$];
  int d[];
  int errors = 0;
  initial begin
    // (1) packed-struct member writes, string and int keys.
    pm["x"] = 16'h0000; pm["x"].a = 8'hCD; pm["x"].b = 8'h3F;
    if (pm["x"] !== 16'hCD3F) begin $display("FAIL pm=%h", pm["x"]); errors++; end
    pi[5].a = 8'hAB;   // missing key: member set, sibling member stays x
    if (pi[5].a !== 8'hAB || pi[5].b !== 8'hxx) begin $display("FAIL pi=%h", pi[5]); errors++; end
    if (pi.num() !== 1) begin $display("FAIL num=%0d", pi.num()); errors++; end
    if (pm["x"].a[7:4] !== 4'hC) begin $display("FAIL readback"); errors++; end

    // (2) const part writes to vec4 assoc elements.
    am["k"] = 16'hFFFF; am["k"][7:0] = 8'h00;
    if (am["k"] !== 16'hFF00) begin $display("FAIL const part=%h", am["k"]); errors++; end
    am["k"][15:12] = 4'hA;
    if (am["k"] !== 16'hAF00) begin $display("FAIL hi part=%h", am["k"]); errors++; end

    // (3) dynamic indexed part writes: assoc, queue, darray.
    am["j"] = 16'h0000;
    for (int j = 0; j < 4; j++) am["j"][j*4 +: 4] = j[3:0];
    if (am["j"] !== 16'h3210) begin $display("FAIL assoc +:=%h", am["j"]); errors++; end
    q.push_back(16'h0000);
    for (int j = 0; j < 4; j++) q[0][j*4 +: 4] = j[3:0];
    if (q[0] !== 16'h3210) begin $display("FAIL q +:=%h", q[0]); errors++; end
    q[0][15 -: 8] = 8'hAB;
    if (q[0] !== 16'hAB10) begin $display("FAIL q -:=%h", q[0]); errors++; end
    d = new[1]; d[0] = 0;
    for (int j = 0; j < 4; j++) d[0][j*8 +: 8] = (j+1);
    if (d[0] !== 32'h04030201) begin $display("FAIL d +:=%h", d[0]); errors++; end

    // (4) compound ops on assoc elements (keep-key RMW path).
    am["c"] = 16'h0010; am["c"] += 16'h0001; am["c"] |= 16'h0100;
    if (am["c"] !== 16'h0111) begin $display("FAIL compound=%h", am["c"]); errors++; end

    // (5) deeper member selects: member + bit/part compose.
    pm["d"] = 16'hFFFF;
    pm["d"].a[3:0] = 4'h0;
    if (pm["d"] !== 16'hF0FF) begin $display("FAIL deep part=%h", pm["d"]); errors++; end
    pm["d"].b[7] = 1'b0;
    if (pm["d"] !== 16'hF07F) begin $display("FAIL deep bit=%h", pm["d"]); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
