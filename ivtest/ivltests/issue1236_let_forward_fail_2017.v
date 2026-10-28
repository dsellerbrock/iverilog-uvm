module issue1236_let_forward_fail_2017;
  logic [7:0] result;
  assign result = identity(8'd42);
  let identity(x) = x;
endmodule
