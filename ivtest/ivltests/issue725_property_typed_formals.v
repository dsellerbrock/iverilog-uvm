module issue725_property_typed_formals;
  logic clk = 0;
  logic [3:0] req = 4'h3;
  logic ack = 0;
  event ev;

  always #5 clk = ~clk;

  sequence seq_base; 1'b1; endsequence
  property prop_base; 1'b1; endproperty
  property prop_arg(property formal_prop); formal_prop; endproperty
  property seq_arg(sequence formal_seq); formal_seq; endproperty
  property event_arg(event formal_event); @(formal_event) 1'b1; endproperty

  property p(logic [3:0] formal_req, logic formal_ack = 1'b0);
    formal_req == req && formal_ack == ack;
  endproperty

  initial begin
    assert property (@(posedge clk) p(req));
    assert property (@(posedge clk) p(8'h13, 8'h10));
    assert property (@(posedge clk) prop_arg(prop_base));
    assert property (@(posedge clk) seq_arg(seq_base));
    assert property (event_arg(ev));
    #12 -> ev;
    #2;
    $display("PASSED");
    $finish;
  end
endmodule
