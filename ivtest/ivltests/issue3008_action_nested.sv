module issue3008_action_nested;
  bit clk, a;
  assert property (@(posedge clk) a) assert property (@(posedge clk) a);
  assert property (@(posedge clk) a) else assume property (@(posedge clk) a);
  assert property (@(posedge clk) a) begin
    if (a) cover property (@(posedge clk) a);
  end else begin
    assert property (@(posedge clk) a);
  end
  cover property (@(posedge clk) a) begin
    assume property (@(posedge clk) a);
  end
  cover sequence (@(posedge clk) a) cover sequence (@(posedge clk) a);
endmodule
