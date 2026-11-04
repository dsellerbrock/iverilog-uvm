`timescale 1ns/1ps
module issue2450_real_delay;
  real big = 1e30;
  initial begin
    fork #(big)  $display("variable 1e30 fired at %h", $time); join_none
    fork #(1e30) $display("literal 1e30 fired at %h", $time); join_none
  end
endmodule
