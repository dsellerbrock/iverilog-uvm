// A method (task/function) call through a virtual interface must dispatch to
// the per-instance task of the actual instance the handle points at.  iverilog
// modelled interface signals as class properties (dynamic, correct) but
// resolved interface METHOD calls statically to the FIRST instance of the
// interface type -- so with two+ instances of the same interface type
// (e.g. OpenTitan's fast + aon clk_rst_if), `vif.task()` ran the wrong
// instance's task and drove the wrong instance's signals.  This stalled
// aon_timer at time 0 (apply_reset drove the wrong clk_rst_if).
//
// Fix: a NetUTask for an interface task carries the runtime vif handle, and
// code generation emits %fork/vif which dispatches to the per-instance task of
// the handle's actual instance (falling back to the static reference target
// for a nil/unresolvable handle, preserving the single-instance path).
interface myif();
  logic [7:0] x = 0;
  task automatic setx(logic [7:0] v); x = v; endtask
endinterface

module vif_method_multi_instance_test;
  myif u_a();
  myif u_b();
  myif u_c();
  typedef virtual myif vif_t;

  vif_t vifs[string];   // assoc array of vifs (OpenTitan cfg.clk_rst_vifs shape)

  initial begin
    vif_t v;
    int ok = 1;
    vifs["a"] = u_a; vifs["b"] = u_b; vifs["c"] = u_c;

    v = u_b;
    v.setx(8'h22);                       // scalar vif variable -> u_b
    #1;
    if (u_b.x !== 8'h22 || u_a.x !== 8'h00) ok = 0;

    u_a.x = 0; u_b.x = 0; u_c.x = 0;
    foreach (vifs[k]) vifs[k].setx(8'hF0);   // each must hit its own instance
    #1;
    if (u_a.x !== 8'hF0 || u_b.x !== 8'hF0 || u_c.x !== 8'hF0) ok = 0;

    if (ok) $display("PASS");
    else    $display("FAIL ua=%h ub=%h uc=%h", u_a.x, u_b.x, u_c.x);
    $finish;
  end
endmodule
