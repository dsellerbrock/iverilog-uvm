module issue708_sequence_event_ce;
  logic clk, ev;
  event pulse;

  sequence boolean_use(event ev);
    @(ev) 1'b1 && ev;
  endsequence

  sequence extra_edge(event ev);
    @(posedge ev) 1'b1;
  endsequence

  sequence data_clock(bit sig);
    @(posedge sig) 1'b1;
  endsequence

  sequence with_clock(event ev);
    @(ev) 1'b1 ##1 1'b1;
  endsequence

  cover property (boolean_use(posedge clk));
  cover property (extra_edge(posedge clk));
  cover property (data_clock(posedge clk));
  cover property (@(posedge clk) 1'b1 ##1 with_clock(negedge clk));
  cover property (@(posedge clk) with_clock(negedge clk).triggered);
  cover property (data_clock(pulse));
endmodule
