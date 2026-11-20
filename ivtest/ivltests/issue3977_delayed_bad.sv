module issue3977_delayed_bad;
  bit clk, a, b;
`ifdef ISSUE3977_ORDINARY_FUNCTION
  function automatic bit identity(bit value);
    return value;
  endfunction
  initial $display("%b", identity(a ##1 b));
`else
  property p(bit data);
    @(posedge clk) data;
  endproperty
  assert property (p(a ##1 b));

  property branched(sequence s);
    (s or a) |-> b;
  endproperty
  assert property (@(posedge clk) branched(a ##1 b));

  property nested(bit enable);
    branched(a ##1 b) or enable;
  endproperty
  assert property (@(posedge clk) nested(1'b0));
`endif
endmodule
