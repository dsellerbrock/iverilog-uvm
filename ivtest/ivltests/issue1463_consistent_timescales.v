`timescale 1ns/1ps

module first;
  initial $display("PASS");
endmodule

module second;
endmodule

module tb;
  first f();
  second s();
endmodule
