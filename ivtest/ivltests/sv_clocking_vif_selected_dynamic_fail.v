interface clocking_vif_dynamic_select_if(input logic clk);
  logic [7:0] raw = '0;
  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_vif_selected_dynamic_fail;
  logic clk = 1'b0;
  clocking_vif_dynamic_select_if vif_if(clk);
  virtual clocking_vif_dynamic_select_if vif;
  integer index = 3;

  always #5 clk = ~clk;

  initial begin
    vif = vif_if;
    #1;
    vif.cb.raw[index] <= 1'b1;
    index = 5;
    #6;
    if (vif_if.raw !== 8'h08)
      $fatal(1, "FAILED selected VIF clocking output did not capture index 3: %h",
             vif_if.raw);
    $display("PASSED");
    $finish;
  end
endmodule
