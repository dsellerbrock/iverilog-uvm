module dut(
  input logic source,
  output logic [15:0] dormant,
  output logic [15:0] active,
  output logic copied
);
  always @* dormant = 16'ha520;
  always_comb active = 16'hb630;
  always @* copied = source;
endmodule

module test;
  logic source;
  wire [15:0] dormant;
  wire [15:0] active;
  wire copied;

  dut u_dut(source, dormant, active, copied);

  initial begin
    source = 1'b0;
    #1;
    if (dormant !== 16'hxxxx)
      $fatal(1, "empty always @* executed: %h", dormant);
    if (active !== 16'hb630)
      $fatal(1, "always_comb did not execute at time zero: %h", active);
    if (copied !== 1'b0)
      $fatal(1, "ordinary always @* failed: %b", copied);

    source = 1'b1;
    #1;
    if (copied !== 1'b1)
      $fatal(1, "ordinary always @* did not retrigger: %b", copied);
    $display("PASSED");
  end
endmodule
