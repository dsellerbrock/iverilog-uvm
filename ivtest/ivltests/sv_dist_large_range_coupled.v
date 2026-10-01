// A dist over huge ranges whose subject is also constrained bitwise
// (IEEE 1800-2017/2023 18.5.4): infeasible values drop out together with their
// share of the weight, so `!base_addr[0]' halves every item and leaves the
// 1:2:1 split unchanged. It failed with "the large-range feasible set cannot
// be resolved exactly" (OpenTitan ibex_icache core sequence base_addr).
class addr_c;
  rand bit [31:0] base_addr;
  constraint c_base_addr {
    base_addr dist { [0:15]                      :/ 1,
                     [16:32'hfffffff0]           :/ 2,
                     [32'hfffffff0:32'hffffffff] :/ 1 };
  }
  constraint c_align { !base_addr[0]; }
endclass

module main;
  int errors;
  initial begin
    addr_c a;
    bit [31:0] v;
    int low, mid, high;
    a = new;
    repeat (300) begin
      if (!a.randomize()) begin $display("FAILED randomize"); errors++; end
      v = a.base_addr;
      if (v[0]) begin $display("FAILED odd %0h", v); errors++; end
      if (v <= 15) low++; else if (v >= 32'hfffffff0) high++; else mid++;
    end
    // Expected 1/4, 1/2, 1/4 of 300; the bounds are about 4.5 sigma wide.
    if (low < 40 || low > 110 || high < 40 || high > 110 || mid < 100 || mid > 200) begin
      $display("FAILED split low=%0d mid=%0d high=%0d", low, mid, high); errors++;
    end
    low = 0; mid = 0; high = 0;
    repeat (300) begin
      if (!std::randomize(v) with {
            v dist { [0:15] :/ 1, [16:32'hfffffff0] :/ 2, [32'hfffffff0:32'hffffffff] :/ 1 };
            !v[0];
          }) begin $display("FAILED std::randomize"); errors++; end
      if (v[0]) begin $display("FAILED std odd %0h", v); errors++; end
      if (v <= 15) low++; else if (v >= 32'hfffffff0) high++; else mid++;
    end
    if (low < 40 || low > 110 || high < 40 || high > 110 || mid < 100 || mid > 200) begin
      $display("FAILED std split low=%0d mid=%0d high=%0d", low, mid, high); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
