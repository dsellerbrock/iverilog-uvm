// IEEE 1800-2017/2023 9.4.2, 25.9: each selected VIF member is an
// independent event source, and the first source cancels its siblings.
`timescale 1ns/1ps

interface aon_mixed_reset_if(input wire rst_n);
endinterface

interface aon_mixed_intr_if(inout wire [1:0] pins);
endinterface

class aon_mixed_cfg;
  virtual aon_mixed_reset_if rst_vif;
  virtual aon_mixed_intr_if intr_vif;
endclass

class aon_mixed_waiter;
  aon_mixed_cfg cfg;
  task automatic mixed();
    @(negedge cfg.rst_vif.rst_n or cfg.intr_vif.pins);
  endtask
  task automatic single();
    @(cfg.intr_vif.pins);
  endtask
endclass

module sv_aon_mixed_vif_edge_wait;
  reg rst_n = 1;
  reg irq_a = 0;
  reg irq_b = 0;
  wire [1:0] pins_a = {irq_a, 1'b0};
  wire [1:0] pins_b = {irq_b, 1'b0};
  aon_mixed_reset_if reset_i(rst_n);
  aon_mixed_intr_if intr_a(pins_a);
  aon_mixed_intr_if intr_b(pins_b);
  aon_mixed_cfg cfg;
  aon_mixed_waiter observer;
  int mixed_hits, single_hits, concrete_hits, same_hits, reset_hits;
  bit rebind_hit, cancelled_hit;

  initial begin
    #100;
    $fatal(1, "timeout in mixed VIF edge wait");
  end

  initial begin
    cfg = new;
    cfg.rst_vif = reset_i;
    cfg.intr_vif = intr_a;
    observer = new;
    observer.cfg = cfg;

    fork
      begin observer.mixed(); mixed_hits++; end
      begin observer.single(); single_hits++; end
      begin @(intr_a.pins); concrete_hits++; end
      begin #2 irq_a = 1; end
    join
    if (mixed_hits != 1 || single_hits != 1 || concrete_hits != 1)
      $fatal(1, "pin event missed mixed=%0d single=%0d concrete=%0d",
             mixed_hits, single_hits, concrete_hits);

    irq_a = 0;
    #1;
    fork
      begin observer.mixed(); same_hits++; end
      begin
        #2;
        irq_a = 1;
        rst_n = 0;
      end
    join
    #1;
    if (same_hits != 1)
      $fatal(1, "same-slot sources resumed %0d times", same_hits);
    rst_n = 1;
    fork
      begin observer.mixed(); same_hits++; end
      begin #2 irq_a = 0; end
    join
    if (same_hits != 2)
      $fatal(1, "rearmed mixed wait missed later pin edge");

    #1;
    fork
      begin observer.mixed(); reset_hits++; end
      begin #2 rst_n = 0; end
    join
    if (reset_hits != 1)
      $fatal(1, "reset negedge missed");

    rst_n = 1;
    irq_b = 0;
    cfg.intr_vif = intr_b;
    #1;
    fork
      begin observer.mixed(); rebind_hit = 1; end
      begin
        #2 irq_a = 1;
        #1;
        if (rebind_hit)
          $fatal(1, "old VIF woke rebound wait");
        irq_b = 1;
      end
    join
    if (!rebind_hit)
      $fatal(1, "rebound VIF did not wake wait");

    irq_b = 0;
    #1;
    fork : cancelled_wait
      begin observer.mixed(); cancelled_hit = 1; end
    join_none
    #1;
    disable cancelled_wait;
    irq_b = 1;
    #1;
    if (cancelled_hit)
      $fatal(1, "cancelled mixed wait woke");

    $display("PASSED");
    $finish(0);
  end
endmodule
