module issue3981_sequence_missing_fail(input bit clk, b);
  sequence s(local input bit x, bit y);
    x ##1 y;
  endsequence

  // Missing required y, after a formal that would create an initializer.
  cover property (@(posedge clk) s(1'b1,));
  cover property (@(posedge clk) s(.x(1'b1), .y()));

  // The positional hole already occupies x.
  cover property (@(posedge clk) s(, .x(1'b1), .y(b)));
endmodule
