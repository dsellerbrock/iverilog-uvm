module test;
  logic clk;
  task automatic t;
    clocking cb @(posedge clk);
    endclocking
  endtask
endmodule
