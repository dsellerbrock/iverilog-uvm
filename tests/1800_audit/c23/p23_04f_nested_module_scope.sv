module outer;
  logic value_from_inner;
  module inner;
    initial value_from_inner = 1'b1;
  endmodule
  inner u();
endmodule

module top;
  outer o();
  initial begin
    #1;
    if (o.value_from_inner !== 1'b1) $fatal(1, "nested module scope failed");
    $display("PASS: nested module scope");
  end
endmodule
