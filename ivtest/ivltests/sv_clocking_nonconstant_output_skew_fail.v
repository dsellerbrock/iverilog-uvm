// Negative: a clocking skew must be a constant expression. Elaborating the
// shared apply path once must report this declaration defect once even when
// multiple static clocking-output drives target the clockvar.
interface clocking_nonconstant_output_skew_if(input logic clk);
  logic raw;
  int runtime_skew = 1;

  clocking cb @(posedge clk);
    output #runtime_skew raw;
  endclocking
endinterface

module sv_clocking_nonconstant_output_skew_fail;
  logic clk;
  clocking_nonconstant_output_skew_if bus(clk);

  initial begin
    bus.cb.raw <= 1'b0;
    bus.cb.raw <= 1'b1;
  end
endmodule
