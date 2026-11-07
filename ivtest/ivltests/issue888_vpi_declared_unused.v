// IEEE 1800-2017/2023 37.17 / 38.23: declared variables are VPI objects
// whether or not anything references them.
module issue888_vpi_declared_unused;
  logic [7:0] unused_logic;
  reg [7:0] unused_reg;
  logic [3:0] live;

  initial begin
    live = 4'hA;
    #1 $check_declared_variables;
  end
endmodule
