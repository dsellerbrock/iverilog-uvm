`timescale 1ns/1ps
module sv_packed_full_feedback_chain;
  logic root;
  logic [2:0] variable_chain;
  wire [2:0] net_chain;

  assign variable_chain[0] = root;
  assign variable_chain[1] = variable_chain[0];
  assign variable_chain[2] = variable_chain[1];
  assign net_chain[0] = root;
  assign net_chain[1] = net_chain[0];
  assign net_chain[2] = net_chain[1];

  task automatic check(input logic [2:0] expected);
    if (variable_chain !== expected || net_chain !== expected)
      $fatal(1, "packed chain variable=%b net=%b expected=%b",
             variable_chain, net_chain, expected);
  endtask

  initial begin
    root = 0;
    #1 check(3'b000);
    root = 1;
    #1 check(3'b111);
    root = 0;
    #1 check(3'b000);
    $display("PASSED");
    $finish(0);
  end
endmodule
