module top;
  if (1) begin : g
    int v;
  end
  initial begin
    top.g.v = 7;
    $display("%0d", top.g.v);
  end
endmodule
