`timescale 1ns/1ps
module packed_two_state_registered_boundary;
  reg clk = 0;
  reg stimulus = 0;
  bit [3:0] two_state;
  logic [2:0] registered;
  reg delayed;

  always #1 clk = ~clk;
  assign two_state[0] = stimulus;
  assign registered[0] = stimulus;
  assign registered[1] = delayed;
  always @(posedge clk) delayed <= registered[0];

  initial begin
    #2;
    if (two_state !== 4'b0000 || registered !== 3'bz00)
      $fatal(1, "initial two-state or registered boundary");
    stimulus = 1;
    #2;
    if (two_state !== 4'b0001 || registered !== 3'bz11)
      $fatal(1, "registered boundary lost delayed update");
    $display("PASS two-state and registered boundaries");
    $finish(0);
  end
endmodule
