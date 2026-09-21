interface mix_if;
  logic [1:0] wake;
endinterface

class mix_cfg;
  virtual mix_if vif;
endclass

module test;
  mix_if bus();
  mix_cfg cfg;
  logic plain;
  int vif_hits, plain_hits;

  initial begin
    cfg = new;
    cfg.vif = bus;
    bus.wake = 0;
    plain = 0;
    #1;

    fork
      begin
        @(posedge (|cfg.vif.wake) or posedge plain);
        vif_hits++;
      end
    join_none
    #1;
    bus.wake = 1;
    #1;
    if (vif_hits != 1) $fatal(1, "VIF arm in mixed event-or was lost");

    bus.wake = 0;
    fork
      begin
        @(posedge (|cfg.vif.wake) or posedge plain);
        plain_hits++;
      end
    join_none
    #1;
    plain = 1;
    #1;
    if (plain_hits != 1) $fatal(1, "ordinary arm in mixed event-or was lost");
    $display("PASSED mixed event-or");
  end
endmodule
