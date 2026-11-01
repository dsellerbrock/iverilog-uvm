`timescale 1 ns / 1 ns
module issue2178_delay_overflow_2023;
  int overflow_delay = -5;
  int max_time_delay = -11;

  initial begin
    #10 fork
      #(overflow_delay) $display("OVERFLOW_DELAY_FIRED");
      #(max_time_delay) $display("MAX_TIME_DELAY_FIRED");
    join_none
    #10 $display("t=%0t", $time);
  end
endmodule
