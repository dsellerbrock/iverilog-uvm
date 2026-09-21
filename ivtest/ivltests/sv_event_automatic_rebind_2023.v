interface rebind_if;
  logic [1:0] wake;
endinterface

class rebind_cfg;
  virtual rebind_if vif;
endclass

class holder;
  rebind_cfg cfg;
endclass

module test;
  rebind_if a(), b();
  holder h0, h1;
  int hits[2];

  task automatic watch(holder local_h, int id);
    @(posedge (|local_h.cfg.vif.wake));
    hits[id]++;
  endtask

  initial begin
    h0 = new; h0.cfg = new; h0.cfg.vif = a;
    h1 = new; h1.cfg = new; h1.cfg.vif = b;
    a.wake = 0; b.wake = 0;
    #1;

    fork
      watch(h0, 0);
      watch(h1, 1);
    join_none
    #1;
    a.wake = 1;
    #1;
    if (hits[0] != 1 || hits[1] != 0)
      $fatal(1, "automatic activations shared a binding: %0d %0d", hits[0], hits[1]);
    b.wake = 1;
    #1;
    if (hits[1] != 1) $fatal(1, "second automatic activation missed edge");

    a.wake = 0; b.wake = 0;
    fork watch(h0, 0); join_none
    #1;
    h0.cfg.vif = a;
    #1;
    if (hits[0] != 1) $fatal(1, "unchanged VIF rebind created an edge");
    b.wake = 1;
    h0.cfg.vif = b;
    #1;
    if (hits[0] != 2) $fatal(1, "changed VIF rebind did not publish its value");

    b.wake = 0;
    h0.cfg.vif = null;
    a.wake = 1;
    #1;
    if (hits[0] != 2) $fatal(1, "idle null/old source changed completed waiter count");
    h0.cfg.vif = b;
    #1;
    fork watch(h0, 0); join_none
    #1;
    b.wake = 1;
    #1;
    if (hits[0] != 3) $fatal(1, "proxy did not rearm after null binding");
    $display("PASSED automatic and rebind boundaries");
  end
endmodule
