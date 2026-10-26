module issue1236_let_forward_fail;
  logic [7:0] result;
  assign result = identity(8'd42);
  let identity(x) = x;
  initial begin
    #0;
    $display("result=%0d", result);
    if (result !== 42) $fatal(1, "result=%0d", result);
  end
endmodule
