module issue917_clocking_sva_positive;
  bit clk = 0;
  bit a = 1;

  always #5 clk = ~clk;

  property outside_same;
    @(posedge clk) a;
  endproperty

  clocking cbp @(posedge clk);
    property p3; a; endproperty
    sequence s3; a; endsequence
    property p3_param(bit value); value; endproperty
    sequence s3_param(value); value; endsequence
    property p_same; outside_same; endproperty
  endclocking

  assert property (cbp.p3)
    else $display("PROPERTY_FAIL %0t", $time);
  assert property (cbp.s3)
    else $display("SEQUENCE_FAIL %0t", $time);
  assert property (cbp.p3_param(a))
    else $display("PARAM_PROPERTY_FAIL %0t", $time);
  assert property (cbp.s3_param(a))
    else $display("PARAM_SEQUENCE_FAIL %0t", $time);
  assert property (cbp.p_same)
    else $display("SAME_EVENT_FAIL %0t", $time);

  initial begin
    #10 a = 0;
    #9 $display("PASSED");
    #1 $finish;
  end
endmodule
