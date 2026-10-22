module m;
  for (genvar i = 0; i < 0; i = i + 1) begin : g
    int v;
  end
  int h;
  initial begin
    h = 3;
    $display("%0d", h);
  end
endmodule
