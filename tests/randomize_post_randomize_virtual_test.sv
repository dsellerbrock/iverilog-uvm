// Regression: randomize() must invoke pre_randomize()/post_randomize() on the
// object's DYNAMIC type, even when called through a base-class handle whose
// static type does not declare the hook (IEEE 1800-2017 §18.6.2 — the hooks
// run on the actual object).
//
// This is the OpenTitan reg-adapter case: a `tl_seq_item` (base) handle points
// to a factory-overridden `cip_tl_seq_item` object whose post_randomize() calls
// set_instr_type(MuBi4False).  iverilog previously resolved the hook from the
// STATIC type, walking only UP the super chain, so a derived-only override was
// never run (a_user.instr_type stayed garbage -> TL command-integrity error).
//
// Fixed via a virtual-hook call (%callf/void/vh) that resolves pre/post_randomize
// on the runtime class and calls the override if present (else skips).

module top;

  class base_item;
    rand bit [31:0] x;
    bit [31:0] pre_tag;
    bit [31:0] post_tag;
    // NOTE: base declares NO pre_/post_randomize (like uvm_sequence_item).
  endclass

  // Derived class adds the hooks (like cip_tl_seq_item).
  class cfg_item extends base_item;
    function void pre_randomize();  pre_tag  = 32'h1111_0000; endfunction
    function void post_randomize(); post_tag = 32'h2222_0000 | (x & 32'hFF); endfunction
  endclass

  initial begin
    base_item b;        // base-typed handle
    cfg_item  c;
    int err = 0;

    c = new();
    b = c;              // base handle -> derived object (factory-override shape)

    // (a) plain randomize() via base handle
    if (!b.randomize() with { x == 32'h44; }) $display("FAIL: randomize returned 0");
    if (c.pre_tag != 32'h1111_0000) begin
      $display("FAIL: pre_randomize not dispatched (pre_tag=0x%08h)", c.pre_tag); err++;
    end
    if (c.post_tag != (32'h2222_0000 | 32'h44)) begin
      $display("FAIL: post_randomize not dispatched (post_tag=0x%08h)", c.post_tag); err++;
    end

    // (b) a plain base object (no hooks) must NOT crash and must skip cleanly
    begin
      base_item p = new();
      if (!p.randomize()) $display("FAIL: base randomize returned 0");
    end

    if (err == 0) $display("PASS");
    else $display("randomize_post_randomize_virtual_test FAILED with %0d errors", err);
    $finish;
  end
endmodule
