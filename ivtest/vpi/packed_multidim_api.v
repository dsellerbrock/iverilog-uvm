module packed_api;
  logic [1:0][2:0] descending = 6'b10_011_1;
  logic [3:4][-1:-2][5:3] ascending = 12'b1010_0110_1100;
  logic [1:0][2:0] memory [5:4];
  wire  [1:0][2:0] packed_net = descending;
  wire  [1:0][2:0] net_memory [7:6];
  assign net_memory[7] = descending;
  assign net_memory[6] = memory[4];
  logic [1:0][2:0] \escaped[unit] ;

  initial begin
    memory[5] = 6'b01_101_0;
    memory[4] = 6'b11_000_1;
    \escaped[unit]  = 6'b11_010_1;
    $packed_api_setup;
    #1 descending[1] = 3'b001; // selected callback
    #1 descending[0] = 3'b111; // sibling must not retrigger [1]
    #1 memory[5][1] = 3'b010;  // compact-array selected callback
    #1 memory[4][1] = 3'b101;  // other word must not retrigger
    #1 $packed_api_check;
  end
endmodule
