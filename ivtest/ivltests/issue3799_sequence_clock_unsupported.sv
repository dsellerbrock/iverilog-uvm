module issue3799_sequence_clock_unsupported;
  bit outer_clk, clk, data;

  sequence sq(c, x);
    @(posedge c) x;
  endsequence

  assert property (@(posedge outer_clk) 1'b1 ##1 sq(clk, data));
  assert property (@(posedge clk) sq(clk, data).triggered);

  sequence fixed_clock(x);
    @(posedge clk) x;
  endsequence
  if (1) begin : shadow
    bit clk;
    assert property (@(posedge clk) 1'b1 ##1 fixed_clock(data));
  end
endmodule
