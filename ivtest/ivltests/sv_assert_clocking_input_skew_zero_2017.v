module main;
  bit clk;
  bit data;

  clocking cb @(posedge clk);
    input #0 data;
  endclocking

  assert property (@(posedge clk) cb.data);
endmodule
