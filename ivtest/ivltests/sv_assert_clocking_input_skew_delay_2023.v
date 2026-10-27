module main;
  bit clk;
  bit data;

  clocking cb @(posedge clk);
    input #3 data;
  endclocking

  assert property (@(posedge clk) cb.data);
endmodule
