module issue727_no_default_disable(input bit clk, input bit start,
                                   input bit done);
  int failures;
  assert property (@(posedge clk) start |=> done) else failures++;
endmodule

module issue727_default_disable_before(input bit clk, input bit start,
                                       input bit done, input bit rst);
  int failures;
  default disable iff rst;
  assert property (@(posedge clk) start |=> done) else failures++;
endmodule

module issue727_default_disable_order;
  bit clk = 0;
  bit start = 1, done;
  bit default_rst, local_rst, property_rst, generate_rst = 1;
  int default_failures, explicit_failures, zero_override_failures;
  int property_failures, generate_failures;

  always #5 clk = ~clk;
  issue727_no_default_disable child(clk, start, done);
  issue727_default_disable_before early_default(clk, start, done,
                                                 default_rst);

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

  generate if (1) begin : local_default
    assert property (@(posedge clk) 1'b0) else generate_failures++;
    default disable iff generate_rst;
  end endgenerate

  initial begin
    @(negedge clk);
    start = 0;
    default_rst = 1;
    property_rst = 1;
    @(posedge clk); #1;
    if (default_failures != 0 || early_default.failures != 0
        || explicit_failures != 1
        || zero_override_failures != 1 || property_failures != 0
        || child.failures != 1 || generate_failures != 0) begin
      $display("FAIL: late-default=%0d early-default=%0d explicit=%0d zero=%0d property=%0d child=%0d",
               default_failures, early_default.failures, explicit_failures,
               zero_override_failures, property_failures, child.failures);
      $fatal(1);
    end
    $display("OBSERVED: late-default=%0d early-default=%0d explicit=%0d zero=%0d property=%0d child=%0d",
             default_failures, early_default.failures, explicit_failures,
             zero_override_failures, property_failures, child.failures);
    $display("STANDARD: late-default=0 early-default=0 explicit=1 zero=1 property=0 child=1");
    $display("GENERATE: local-late-default failures=%0d", generate_failures);
    $finish;
  end

  // IEEE 1800-2017/2023 16.15: declaration position does not limit scope.
  default disable iff default_rst;
endmodule
