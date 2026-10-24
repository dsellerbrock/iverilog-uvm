module test;
  wire clk = 0;
  reg q;
  clocking cb @(posedge clk);
    output q;
  endclocking

  reg val;
  initial val = cb.q;
endmodule
