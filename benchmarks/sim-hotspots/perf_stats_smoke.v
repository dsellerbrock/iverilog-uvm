module perf_stats_smoke;
  reg a, b;
  wire c;
  assign c = a & b;
  initial begin
    a = 0; b = 0;
    #1 a = 1;
    #1 b = 1;
    $display("perf-stats-smoke c=%b", c);
    $finish;
  end
endmodule
