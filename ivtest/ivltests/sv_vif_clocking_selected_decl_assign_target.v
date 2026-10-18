// A selected VIF clockvar target preserves the other packed bits.
interface target_select_if(input logic clk);
  generate
    if (1) begin : child
      logic [7:0] raw;
    end
  endgenerate
  wire [3:0] nib;

  clocking cb @(posedge clk);
    output nib = child.raw[3:0];
  endclocking
endinterface

module sv_vif_clocking_selected_decl_assign_target;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  target_select_if intf(clk);
  virtual target_select_if vif;

  initial begin
    intf.child.raw = 8'h5c;
    vif = intf;
    #1 vif.cb.nib <= 4'h5;
    @(posedge clk);
    #1;
    if (intf.child.raw !== 8'h55)
      $fatal(1, "selected VIF target changed the wrong bits: %h",
             intf.child.raw);
    $display("PASSED");
    $finish;
  end
endmodule
