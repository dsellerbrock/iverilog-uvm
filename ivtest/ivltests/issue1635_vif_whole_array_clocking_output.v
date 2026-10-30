interface issue1635_aif(input logic clk);
  logic [7:0] q [0:1];
  clocking cb @(posedge clk); output q; endclocking
endinterface

module issue1635_vif_whole_array_clocking_output;
  logic clk = 0;
  always #5 clk = ~clk;
  issue1635_aif bus(clk);
  virtual issue1635_aif vif;

  initial begin
    vif = bus;
    #1 vif.cb.q <= '{8'haa, 8'hbb};
    @(posedge clk); #1;
    if (bus.q[0] !== 8'haa || bus.q[1] !== 8'hbb)
      $fatal(1, "whole-array virtual-interface clocking drive failed: %h %h",
             bus.q[0], bus.q[1]);
    $display("q %h %h", bus.q[0], bus.q[1]);
    $finish;
  end
endmodule
