checker issue2907_no_clock_c(logic s, event clock = $inferred_clock);
  a: assert property (@clock s);
endchecker
module issue2907_no_clock;
  logic s;
  issue2907_no_clock_c u(s);
endmodule
