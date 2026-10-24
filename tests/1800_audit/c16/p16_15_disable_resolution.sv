module no_default_disable(input bit clk, input bit start, input bit done);
  int failures;
  assert property (@(posedge clk) start |=> done) else failures++;
endmodule

module default_disable_before(input bit clk, input bit start, input bit done,
                              input bit rst);
  int failures;
  default disable iff rst;
  assert property (@(posedge clk) start |=> done) else failures++;
endmodule

module test;
  bit clk = 0;
  bit start = 1, done;
  bit default_rst, local_rst, property_rst;
  int default_failures, explicit_failures, zero_override_failures;
  int property_failures;

  always #5 clk = ~clk;
  no_default_disable child(clk, start, done);
  default_disable_before early_default(clk, start, done, default_rst);

  assert property (@(posedge clk) start |=> done)
    else default_failures++;
  assert property (@(posedge clk) disable iff (local_rst) start |=> done)
    else explicit_failures++;
  assert property (@(posedge clk) disable iff (1'b0) start |=> done)
    else zero_override_failures++;

  property p_property_disable;
    disable iff (property_rst) start |=> done;
  endproperty
  assert property (@(posedge clk) p_property_disable) else property_failures++;

  initial begin
    @(negedge clk);
    start = 0;
    default_rst = 1;
    property_rst = 1;
    @(posedge clk); #1;
    if (default_failures != 1 || early_default.failures != 0
        || explicit_failures != 1
        || zero_override_failures != 1 || property_failures != 0
        || child.failures != 1) begin
      $display("FAIL: late-default=%0d early-default=%0d explicit=%0d zero=%0d property=%0d child=%0d",
               default_failures, early_default.failures, explicit_failures,
               zero_override_failures, property_failures, child.failures);
      $fatal(1);
    end
    $display("OBSERVED: late-default=%0d early-default=%0d explicit=%0d zero=%0d property=%0d child=%0d",
             default_failures, early_default.failures, explicit_failures,
             zero_override_failures, property_failures, child.failures);
    $display("STANDARD: late-default=0 early-default=0 explicit=1 zero=1 property=0 child=1");
    $finish;
  end

  // Clause 16.15 requires this declaration to apply throughout module scope,
  // independent of its textual position.
  default disable iff default_rst;
endmodule
