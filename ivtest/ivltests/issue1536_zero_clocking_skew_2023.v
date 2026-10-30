module issue1536_zero_clocking_skew_2023;
  logic clk, d, q;
  clocking cb @(posedge clk);
    input #0 d;
    output #0 q;
  endclocking
endmodule
