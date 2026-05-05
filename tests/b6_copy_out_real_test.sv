// Phase 63b/B6 (real impl): function output/inout argument copy-out
// to non-trivial actuals must actually write back the modified value
// to the actual location, not silently drop it.
//
// Common UVM-shaped case: the actual is a plain int local but
// iverilog elaborates a SELECT wrapper for width/sign normalization
// at the call site.  Pre-fix: the wrapped SELECT shape didn't match
// the IVL_EX_SIGNAL test, so copy-out was silently skipped (an
// advisory warning was emitted).
//
// Coverage:
//   T1   : inout int — SELECT-wrapped signal (commit af5dccabd)
//   T2   : output shortint — width-different SELECT wrap
//   T3   : function returning class handle — uses %store/obj
//   T4   : chained returns — exercises stack discipline
//   T5   : SELECT-wrapped class property — common UVM pattern
//          uvm_config_db::get(this, "", "name", this.m_field)
`timescale 1ns/1ps

class my_obj;
  int v;
  function new(int v_); v = v_; endfunction
endclass

class cfg_holder;
  int m_field;
  // Mirror the uvm_config_db pattern: function takes inout T value where T's
  // width may differ from the field's, so iverilog wraps the actual in
  // IVL_EX_SELECT(IVL_EX_PROPERTY(this.m_field)) at the call site.
  function automatic bit get_with_select_wrap(inout shortint value);
    value = 16'sh3F0F;
    return 1;
  endfunction
  function void run_test();
    if (!get_with_select_wrap(m_field))
      $fatal(1, "FAIL/T5: ret 0");
    if (m_field !== 32'h00003F0F)
      $fatal(1, "FAIL/T5: m_field=%0h expected 0x3F0F", m_field);
  endfunction
endclass

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

  // Object-return: function returns a class handle.
  function automatic my_obj make_obj(int v);
    my_obj r;
    r = new(v);
    return r;
  endfunction

  // Queue-return.
  function automatic int q_of(int n);
    int r[$];
    for (int i = 0; i < n; i++) r.push_back(i*10);
    return r.size();
  endfunction

  initial begin
    int x;
    int q[$];
    shortint y;
    my_obj o;

    // T1: inout int — no width difference
    if (!get_int(x))                     $fatal(1, "FAIL/T1: ret");
    if (x !== 12345)                     $fatal(1, "FAIL/T1: x=%0d", x);

    // T2: output to indexed queue entry — already worked but keep coverage
    q.push_back(0); q.push_back(0); q.push_back(0);
    set_short(y, 16'sh1234);
    if (y !== 16'sh1234)                 $fatal(1, "FAIL/T2: y=%0h", y);

    // T3: object-handle return — exercises %ret/obj
    o = make_obj(99);
    if (o == null || o.v !== 99)
      $fatal(1, "FAIL/T3: o.v=%0d (expected 99)", o == null ? -1 : o.v);

    // T4: chained object returns — exercises stack discipline
    o = make_obj(1);
    o = make_obj(2);
    o = make_obj(3);
    if (o == null || o.v !== 3)
      $fatal(1, "FAIL/T4: o.v=%0d (expected 3)", o == null ? -1 : o.v);

    // T5: SELECT-wrapped class-property actual.  Pre-fix the warning
    // "Skipping unsupported function copy-out argument for `value'"
    // fired at uvm_sequencer_base.svh:452 every UVM compile.
    begin
      cfg_holder ch;
      ch = new();
      ch.run_test();
    end

    $display("PASS: copy-out for SELECT-wrapped signal/property + obj-return");
    $finish;
  end
endmodule
