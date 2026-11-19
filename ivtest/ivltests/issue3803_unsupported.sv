module issue3803_unsupported;
  logic clk, clk1, clk2;
  logic a, b, c;

  sequence fixed_s;
    @(posedge clk) a ##1 @(posedge clk1) b;
  endsequence
  sequence coincident_s;
    @(posedge clk) a ##1 @(posedge clk1) b ##0 @(posedge clk2) c;
  endsequence
  sequence variable_s;
    @(posedge clk) a ##1 @(posedge clk1) b ##[1:2] c ##1 @(posedge clk2) a;
  endsequence

  property coincident_p;
    fixed_s |=> coincident_s;
  endproperty
  property variable_p;
    fixed_s |=> variable_s;
  endproperty
  property procedural_p;
    fixed_s |=> fixed_s;
  endproperty

  assert property (coincident_p);
  assert property (variable_p);
  initial assert property (procedural_p);
endmodule
