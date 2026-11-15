module top;
  reg value;
  wire [1:0] pull_bit, resolved_bit, gate_bit, assign_bit, strong_bit;
  pullup (pull_bit[0]);
  pulldown (resolved_bit[1]);
  assign (weak0, weak1) resolved_bit[1] = value;
  buf (weak0, weak1) (gate_bit[0], value);
  assign (weak0, weak1) assign_bit[1] = value;
  assign strong_bit[1] = value;

  initial begin
    value = 1'b1;
    #1 $display("one:  %v %v %v %v %v", pull_bit, resolved_bit, gate_bit, assign_bit, strong_bit);
    value = 1'b0;
    #1 $display("zero: %v %v %v %v %v", pull_bit, resolved_bit, gate_bit, assign_bit, strong_bit);
    value = 1'bz;
    #1 $display("z:    %v %v %v %v %v", pull_bit, resolved_bit, gate_bit, assign_bit, strong_bit);
    value = 1'bx;
    #1 $display("x:    %v %v %v %v %v", pull_bit, resolved_bit, gate_bit, assign_bit, strong_bit);
  end
endmodule
