module issue727_early_control(input logic clk, rst,
                              output integer failures);
  initial failures = 0;

  default disable iff (rst);
  assert property (@(posedge clk) 1'b0) else failures++;
endmodule

module issue727_no_default_child(input logic clk, rst,
                                 output integer failures);
  initial failures = 0;

  // A module instance does not inherit its parent's default disable.
  assert property (@(posedge clk) 1'b0) else failures++;
endmodule

module issue727_late_child(input logic clk, rst,
                           output integer failures);
  initial failures = 0;

  assert property (@(posedge clk) 1'b0) else failures++;
  default disable iff (rst);
endmodule

module issue727_default_disable_order;
  logic clk = 0;
  logic rst = 1;
  integer late_failures = 0;
  integer explicit_failures = 0;
  integer property_failures = 0;
  integer early_failures;
  integer no_default_failures;
  integer child_late_failures;
  integer errors = 0;

  always #5 clk = ~clk;

  issue727_early_control early(clk, rst, early_failures);
  issue727_no_default_child no_default(clk, rst, no_default_failures);
  issue727_late_child late_child(clk, rst, child_late_failures);

  property property_override;
    disable iff (1'b0) 1'b0;
  endproperty

  // Both assertions precede the same-scope default declaration below.
  assert property (@(posedge clk) 1'b0) else late_failures++;
  assert property (@(posedge clk) disable iff (1'b0) 1'b0)
    else explicit_failures++;
  assert property (@(posedge clk) property_override)
    else property_failures++;

  default disable iff (rst);

  initial begin
    repeat (2) @(posedge clk);
    #1;

    if (late_failures != 0) begin
      $display("FAIL late default did not disable assertion: %0d",
               late_failures);
      errors++;
    end
    if (early_failures != 0) begin
      $display("FAIL earlier default did not disable assertion: %0d",
               early_failures);
      errors++;
    end
    if (child_late_failures != 0) begin
      $display("FAIL child late default did not disable assertion: %0d",
               child_late_failures);
      errors++;
    end
    if (explicit_failures == 0 || property_failures == 0) begin
      $display("FAIL assertion/property disable override was ignored");
      errors++;
    end
    if (no_default_failures == 0) begin
      $display("FAIL parent default leaked into module instance");
      errors++;
    end

    rst = 0;
    repeat (2) @(posedge clk);
    #1;
    if (late_failures == 0) begin
      $display("FAIL late-default assertion stayed disabled after reset");
      errors++;
    end
    if (child_late_failures == 0) begin
      $display("FAIL child assertion stayed disabled after reset release");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
    $finish;
  end
endmodule
