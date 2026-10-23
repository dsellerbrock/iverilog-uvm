module sv_clocking_end_label;
  bit clk;

  clocking cb @(posedge clk);
  endclocking : cb

  default clocking default_cb @(posedge clk);
  endclocking : default_cb

  global clocking global_cb @(posedge clk);
  endclocking : global_cb

  initial begin
    $display("PASSED");
    $finish;
  end
endmodule
