interface rebind_stress_if;
  logic wake;
endinterface

class rebind_stress_cfg;
  virtual rebind_stress_if vif;
endclass

module test;
  rebind_stress_if a(), b();
  rebind_stress_cfg cfg;
  int hits;

  initial begin
    cfg = new;
    cfg.vif = a;
    a.wake = 0;
    b.wake = 0;
    #1;

    for (int i = 0; i < 200; i++) begin
      fork begin
        @(posedge (|cfg.vif.wake));
        hits++;
      end join_none
      #1;
      if (i[0]) begin
        a.wake = 1;
        cfg.vif = a;
      end else begin
        b.wake = 1;
        cfg.vif = b;
      end
      #1;
      if (hits != i + 1)
        $fatal(1, "rebind iteration %0d produced %0d hits", i, hits);
      a.wake = 0;
      b.wake = 0;
      #1;
    end
    $display("PASSED 200 repeated rebinds");
  end
endmodule
