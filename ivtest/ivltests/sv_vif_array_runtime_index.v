// M5-3: runtime-index binding of a virtual-interface array from an array of
// interface INSTANCES (IEEE 1800-2017 25.9). `vp[i] = pins[i]` in a loop, and
// any `pins[expr]` used as a virtual-interface value with a non-constant
// index, requires a runtime instance-dispatch table: interface instances are
// scopes and a scope index must be constant, so the elaborator synthesizes a
// select over the N instance handles (out-of-range -> null).
// Self-checking: prints PASSED only when every binding is correct.
interface simple_if;
  logic [7:0] d;
endinterface

module sv_vif_array_runtime_index;
  simple_if pins[4]();
  virtual simple_if vp[4];
  virtual simple_if vsel;
  int idx;
  int errors = 0;

  initial begin
    // Runtime-index loop binding of the whole array.
    for (int i = 0; i < 4; i++) vp[i] = pins[i];
    pins[0].d = 8'h10; pins[1].d = 8'h21; pins[2].d = 8'h32; pins[3].d = 8'h43;
    #1;
    for (int i = 0; i < 4; i++)
      if (vp[i].d !== (8'h10 + i*8'h11)) begin
        $display("FAILED loop vp[%0d].d=%0h", i, vp[i].d); errors++;
      end

    // Direct (non-loop) variable index used as a virtual-interface r-value.
    idx = 2; vsel = pins[idx]; #1;
    if (vsel.d !== 8'h32) begin $display("FAILED varidx=2 vsel.d=%0h", vsel.d); errors++; end
    idx = 0; vsel = pins[idx]; #1;
    if (vsel.d !== 8'h10) begin $display("FAILED varidx=0 vsel.d=%0h", vsel.d); errors++; end

    // Out-of-range index yields a null handle.
    idx = 9; vsel = pins[idx];
    if (vsel != null) begin $display("FAILED oob not null"); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
