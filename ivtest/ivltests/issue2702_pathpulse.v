`timescale 1ns/1ns
module issue2702_buf(input a, output y);
  assign y = a;
  specify (a => y) = 4; endspecify
endmodule

module issue2702_pathpulse;
  reg a = 0;
  wire y;
  issue2702_buf u(a, y);

  always @(y) $display("Y %0t %b", $time, y);

  initial begin
    #10 a = 1;
    #1 a = 1'bx;
  end
endmodule
