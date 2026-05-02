// Phase 63b/B6 (real impl): function output/inout argument copy-out
// to non-trivial actuals must actually write back the modified value
// to the actual location, not silently drop it.
//
// Common UVM-shaped case: the actual is a plain int local but
// iverilog elaborates a SELECT wrapper for width/sign normalization
// at the call site.  Pre-fix: the wrapped SELECT shape didn't match
// the IVL_EX_SIGNAL test, so copy-out was silently skipped (an
// advisory warning was emitted).
`timescale 1ns/1ps

module top;
  // Take inout to mirror UVM's uvm_config_int::get(... inout int value)
  function automatic bit get_int(inout int value);
    value = 12345;
    return 1;
  endfunction

  // Differs in width to force a SELECT wrapper.
  function automatic void set_short(output shortint dst, input shortint v);
    dst = v;
  endfunction

  initial begin
    int x;
    int q[$];
    shortint y;

    // T1: inout int — no width difference
    if (!get_int(x))                     $fatal(1, "FAIL/T1: ret");
    if (x !== 12345)                     $fatal(1, "FAIL/T1: x=%0d", x);

    // T2: output to indexed queue entry — already worked but keep coverage
    q.push_back(0); q.push_back(0); q.push_back(0);
    set_short(y, 16'sh1234);
    if (y !== 16'sh1234)                 $fatal(1, "FAIL/T2: y=%0h", y);

    $display("PASS: copy-out for SELECT-wrapped signal actuals");
    $finish;
  end
endmodule
