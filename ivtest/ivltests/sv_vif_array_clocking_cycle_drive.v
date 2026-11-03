// IEEE 1800-2017/2023 14.16: cycle delays use the selected clockvar's clock.
`timescale 1ns/1ns

interface array_cycle_if(input logic clk);
  logic [7:0] q = 0;
  clocking cb @(posedge clk); output q; endclocking
endinterface

class array_cycle_leaf;
  virtual array_cycle_if vif;
endclass

module sv_vif_array_clocking_cycle_drive;
  logic clk = 0;
  always #5 clk = ~clk;
  array_cycle_if b0(clk), b1(clk);
  array_cycle_leaf leaves[2];
  int errors = 0;

  function automatic int pick(); return 1; endfunction

  initial begin
    leaves[0] = new; leaves[1] = new;
    leaves[0].vif = b0; leaves[1].vif = b1;

    @(b0.cb);
    leaves[pick()].vif.cb.q <= ##1 8'h44;
    @(b0.cb); #1;
    if (b1.q !== 8'h44) begin
      $display("FAILED: call-indexed drive got %h", b1.q);
      errors++;
    end

    leaves[1].vif.cb.q <= ##1 8'h55;
    @(b0.cb); #1;
    if (b1.q !== 8'h55) begin
      $display("FAILED: constant-indexed drive got %h", b1.q);
      errors++;
    end

    if (errors != 0) $fatal(1, "%0d clocking-drive checks failed", errors);
    $display("PASSED");
    $finish;
  end

  initial begin
    #100;
    $fatal(1, "clocking-drive watchdog expired");
  end
endmodule
