`timescale 1 ns / 1 ns
module issue2177_negative_constant_delay;
  int n = -5;
  parameter int P = -3;

  initial begin
    fork
      #(P) $display("ISSUE2177_PARAM=%0t", $time);
    join_none
    #(n) $display("ISSUE2177_VARIABLE=%0t", $time);
    $display("PASSED");
  end
endmodule
