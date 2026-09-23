`timescale 1ns/1ps

interface reset_if(input wire rst_n);
endinterface

interface interrupt_if(inout wire [1:0] pins);
endinterface

class aon_cfg;
  virtual reset_if rst_vif;
  virtual interrupt_if intr_vif;
endclass

class waiter;
  aon_cfg cfg;

  task automatic mixed();
    @(negedge cfg.rst_vif.rst_n or cfg.intr_vif.pins);
  endtask

  task automatic single();
    @(cfg.intr_vif.pins);
  endtask
endclass

module top;
  reg rst_n = 1'b1;
  reg irq = 1'b0;
  wire [1:0] pins = {irq, 1'b0};
  reset_if reset_i(rst_n);
  interrupt_if interrupt_i(pins);
  aon_cfg cfg;
  waiter observer;
  bit mixed_hit, single_hit, concrete_hit;

  initial begin
    cfg = new;
    cfg.rst_vif = reset_i;
    cfg.intr_vif = interrupt_i;
    observer = new;
    observer.cfg = cfg;

    fork
      begin
        observer.mixed();
        mixed_hit = 1;
        $display("MIXED_WAKE pins=%b time=%0t", cfg.intr_vif.pins, $time);
      end
      begin
        observer.single();
        single_hit = 1;
        $display("SINGLE_VIF_WAKE pins=%b time=%0t", cfg.intr_vif.pins, $time);
      end
      begin
        @(interrupt_i.pins);
        concrete_hit = 1;
        $display("CONCRETE_WAKE pins=%b time=%0t", interrupt_i.pins, $time);
      end
      begin
        #10;
        irq = 1'b1;
      end
    join_none

    #100;
    if (mixed_hit && single_hit && concrete_hit) begin
      $display("PASS mixed, single-VIF, and concrete waits woke");
      $finish;
    end
    $fatal(1, "RED mixed=%0d single=%0d concrete=%0d pins=%b",
           mixed_hit, single_hit, concrete_hit, interrupt_i.pins);
  end
endmodule
