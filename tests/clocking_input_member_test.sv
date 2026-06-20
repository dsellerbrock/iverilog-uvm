// Regression: reading a module-level clocking-block INPUT member
// (`cb.sig`) must resolve to the underlying signal, not fall through to
// the "Unable to bind wire/reg/memory" path.
//
// Before the fix, `mon_cb.sig` in a *module* never resolved: symbol_search
// does not model module-level clocking blocks as scopes, and the only
// clocking-member rewrite (rewrite_interface_clocking_member_path_via_scope_)
// required the enclosing scope to be an *interface* with a >=3-component
// path.  So `mon_cb.sig` fell to the unbind warning, returned null, and the
// $display argument printed constant garbage (8-bit 0x20) regardless of the
// real 1-bit signal value.
//
// The fix extends that helper with a module-level fallback that walks up to
// the enclosing MODULE and consults its pform clocking_blocks, rewriting
// `cb.sig` -> `sig`.
//
// NOTE (honest scope): this is a FLAT, UNSAMPLED rewrite — it reads the
// underlying signal's live value, not a preponed clocking sample.  This test
// uses #1-offset transitions only (no edge-aligned changes), so the flat read
// equals the sampled value here.  A green result proves "clocking input member
// resolves to the underlying signal" — it does NOT prove clocking sampling
// semantics are implemented.

module top;
  logic clk = 0;
  always #5 clk = ~clk;

  logic sig;

  clocking mon_cb @(posedge clk);
    input sig;
  endclocking

  // Drive sig: 0 until just after the 3rd posedge, 1 for one cycle, then 0.
  initial begin
    sig = 0;
    repeat (3) @(posedge clk);  // posedges at 5,15,25
    #1 sig = 1;                 // t=26
    @(posedge clk);             // posedge at 35
    #1 sig = 0;                 // t=36
  end

  // Expected mon_cb.sig at posedges 5,15,25,35,45,55,65,75:
  //   0,0,0,1,0,0,0,0
  initial begin
    int errors = 0;
    logic exp [8] = '{0,0,0,1,0,0,0,0};
    for (int i = 0; i < 8; i++) begin
      @(mon_cb);
      if (mon_cb.sig !== exp[i]) begin
        $display("FAIL @%0t: mon_cb.sig=%b expected=%b (raw sig=%b)",
                 $time, mon_cb.sig, exp[i], sig);
        errors++;
      end
    end
    if (errors == 0) $display("PASS");
    else $display("clocking_input_member_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
