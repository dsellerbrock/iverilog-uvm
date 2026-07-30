// IEEE 1800-2017 8.20: an override of a virtual method is virtual even
// without the keyword. Base hooks below have EMPTY bodies (the UVM
// task-phase shape) and the design contains exactly ONE override,
// declared WITHOUT the `virtual` keyword. A base-class receiver must
// run the (empty) base body — not the override.
class base_c;
  virtual task hook(int x);
  endtask
  virtual function void fhook(int x);
  endfunction
endclass

class derived_c extends base_c;
  int d_hits = 0;
  // NOTE: no `virtual` keyword — implicit per 8.20.
  task hook(int x);
    d_hits += x;
  endtask
  function void fhook(int x);
    d_hits += 100 * x;
  endfunction
endclass

module top;
  base_c b, h;
  derived_c d;
  int fails = 0;
  initial begin
    b = new; d = new;

    // 1. Base receiver: empty base body must run; the canary derived
    //    object must remain untouched (pre-fix: derived body ran with a
    //    base-class `this` — silent corruption / crash risk).
    h = b;
    h.hook(5);
    h.fhook(3);
    if (d.d_hits != 0) begin fails++; $display("FAIL: base receiver ran the override (d_hits=%0d)", d.d_hits); end

    // 2. Derived receiver through base handle: override must run.
    h = d;
    h.hook(7);
    if (d.d_hits != 7) begin fails++; $display("FAIL: derived hook, d_hits=%0d expect 7", d.d_hits); end
    h.fhook(2);
    if (d.d_hits != 207) begin fails++; $display("FAIL: derived fhook, d_hits=%0d expect 207", d.d_hits); end

    // 3. Direct call unchanged.
    d.hook(1);
    if (d.d_hits != 208) begin fails++; $display("FAIL: direct hook, d_hits=%0d expect 208", d.d_hits); end

    if (fails == 0) $display("PASS");
    else $display("FAIL count=%0d", fails);
  end
endmodule
