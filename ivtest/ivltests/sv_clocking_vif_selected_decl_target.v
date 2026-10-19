interface vif_selected_decl_target_if(input logic clk);
  generate
    if (1) begin : child
      logic [7:0] raw;
    end
  endgenerate
  logic [3:0] nib;

  clocking cb @(posedge clk);
    output nib = child.raw[7:4];
  endclocking
endinterface

module sv_clocking_vif_selected_decl_target;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  vif_selected_decl_target_if intf(clk);
  virtual vif_selected_decl_target_if vif;

  initial begin
    intf.child.raw = 8'h5c;
    vif = intf;
    #1 vif.cb.nib <= 4'ha;
    @(posedge clk);
    #1;
    if (intf.child.raw !== 8'hac)
      $fatal(1, "selected VIF declaration target was not driven: %h",
             intf.child.raw);
    $display("PASSED");
    $finish;
  end
endmodule
