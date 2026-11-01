module issue726_property_local_formals;
  logic clk = 0;
  logic a = 1;
  int actual = 1;

  always #5 clk = ~clk;

  // The local formal must retain the value sampled when this attempt starts.
  always @(negedge clk) begin
    if ($time == 10) begin
      actual = 0;
      a = 0;
    end
  end

  property snapshot(local input int value);
    a |-> ##1 (value == 1);
  endproperty

  // Direction and type are inherited by the following bare formal.
  property inherited(local int first = 3, second);
    (first == 3) && (second == 4);
  endproperty

  property defaulted(local int value = 3);
    value == 3;
  endproperty

  property converted(local input logic [3:0] value);
    value == 4'h5;
  endproperty

  ap_snapshot: assert property (@(posedge clk) snapshot(actual))
    else $fatal(1, "local property formal did not snapshot");
  ap_inherited: assert property (@(posedge clk) inherited(3, 4))
    else $fatal(1, "inherited local property formals failed");
  ap_defaulted: assert property (@(posedge clk) defaulted())
    else $fatal(1, "default local property formal failed");
  ap_converted: assert property (@(posedge clk) converted(8'h15))
    else $fatal(1, "typed local property formal failed");

  initial begin
    #21;
    $display("PASSED");
    $finish;
  end
endmodule
