module issue1239_global_clocking_generate;
  logic clk;
  generate if (1) begin : g
    global clocking gc @(posedge clk);
    endclocking
  end endgenerate
endmodule
