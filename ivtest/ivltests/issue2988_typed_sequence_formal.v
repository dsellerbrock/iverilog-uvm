module issue2988_typed_sequence_formal;
  bit clk = 0;
  sequence assign_formal(int x); (1'b1, x = 2); endsequence
  sequence compound_formal(int x); (1'b1, x += 1); endsequence
  sequence increment_formal(int x); (1'b1, x++); endsequence
  property p;
    int value;
    @(posedge clk) assign_formal(value) ##1 compound_formal(value)
                   ##1 increment_formal(value);
  endproperty
  assert property (p);
  initial begin #5 clk = 1; #1 $finish; end
endmodule
