module issue3979_invalid_actual;
  bit clk, a, b;
  property overlap(sequence q);
    q |-> 1'b1;
  endproperty
  property sequence_property(sequence q);
    q;
  endproperty
  assert property (@(posedge clk) overlap(a[*0]));
  assert property (@(posedge clk) sequence_property(a[*0] or b));
  property event_clock(event e);
    @(e) 1'b1;
  endproperty
  assert property (event_clock((a intersect b) or clk));
  assert property (event_clock((a intersect b) or posedge clk));
endmodule
