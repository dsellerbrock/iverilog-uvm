interface clocking_param_width_if #(parameter int WIDTH = 8)
                                   (input logic clk);
  logic [WIDTH-1:0] raw;

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_param_if_width;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  clocking_param_width_if #(.WIDTH(13)) bus(clk);

  initial begin
    bus.raw = '0;
    #1 bus.cb.raw <= 13'h15a7;
    @(posedge clk);
    #1;
    if (bus.raw !== 13'h15a7)
      $fatal(1, "parameterized clocking output width changed: %h", bus.raw);
    $display("PASSED");
    $finish;
  end
endmodule
