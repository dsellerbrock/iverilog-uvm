// IEEE 1800-2023 16.10: assignment to a property local applies the local's
// declared type before the value flows to a later sequence expression.
module sv_assert_property_local_declared_type;
  logic clk = 0;
  logic start = 0;
  logic [31:0] source = 0;
  int failures = 0;

  always #5 clk = ~clk;

  property declared_conversions(enable);
    logic [7:0] narrowed;
    int signed_value;
    logic scalar_value;
    @(posedge clk)
      (enable, narrowed = source) ##0
      (1'b1, signed_value = source) ##0
      (1'b1, scalar_value = source[0]) |=>
      (narrowed == 8'h00 && signed_value < 0 && !scalar_value);
  endproperty

  sequence declared_sequence_conversion(enable);
    logic [7:0] sequence_narrowed;
    (enable, sequence_narrowed = source) ##1
      (sequence_narrowed == 8'h00);
  endsequence

  ap: assert property (declared_conversions(start))
        else failures++;
  as: assert property (@(posedge clk)
        start |-> declared_sequence_conversion(start))
        else failures++;

  initial begin
    @(negedge clk);
    start = 1;
    source = 32'hffff_ff00;
    @(negedge clk);
    start = 0;
    source = 0;
    repeat (2) @(negedge clk);
    if (failures != 0)
      $fatal(1, "declared property-local conversion failed");
    $display("PASSED");
    $finish;
  end
endmodule
