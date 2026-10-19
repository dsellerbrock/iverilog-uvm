// A selected clocking declaration-assignment target retains its selection
// through synchronous output buffering.
interface clocking_selected_decl_assign_if(input logic clk);
  generate
    if (1) begin : u
      logic [7:0] raw;
    end
  endgenerate
  logic [3:0] nib;

  clocking cb @(posedge clk);
    output nib = u.raw[7:4];
  endclocking
endinterface

module sv_clocking_selected_decl_assign_target;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  clocking_selected_decl_assign_if bus(clk);

  initial begin
    bus.u.raw = 8'h5c;
    #1 bus.cb.nib <= 4'ha;
    @(posedge clk);
    #1;
    if (bus.u.raw !== 8'hac)
      $fatal(1, "selected declaration target changed the wrong bits: %h",
             bus.u.raw);
    $display("PASSED");
    $finish;
  end
endmodule
