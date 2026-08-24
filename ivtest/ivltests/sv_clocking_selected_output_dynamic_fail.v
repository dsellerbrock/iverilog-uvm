// A dynamic selected clocking output needs one captured selector so the
// output buffer, current-event destination, and pending mask cannot diverge.
module sv_clocking_selected_output_dynamic_fail;
  logic clk;
  logic [7:0] raw;
  wire [7:0] bus;
  integer idx = 3;

  clocking cb @(posedge clk);
    output bus = raw;
  endclocking

  initial cb.bus[idx] <= 1'b1;
endmodule
