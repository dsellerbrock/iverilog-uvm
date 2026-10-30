`timescale 1ns/1ps

module sv_clocking_inout_alias;
  logic clk = 1'b0;
  logic raw = 1'b0;

  clocking cb @(posedge clk);
    inout alias_v = raw;
  endclocking

  initial begin
    #1 clk = 1'b1;
    #1;
    if (cb.alias_v !== 1'b0)
      $fatal(1, "inout alias did not sample raw: %b", cb.alias_v);

    clk = 1'b0;
    raw = 1'b1;
    #1 clk = 1'b1;
    #1;
    if (cb.alias_v !== 1'b1)
      $fatal(1, "inout alias did not resample raw: %b", cb.alias_v);

    $display("PASS");
    $finish;
  end
endmodule
