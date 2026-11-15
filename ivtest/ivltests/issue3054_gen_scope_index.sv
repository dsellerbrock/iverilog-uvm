module top;
  for (genvar i = -2; i <= 2; i += 2) begin : g
    for (genvar j = 3; j <= 4; j++) begin : inner
    end
  end
  if (1) begin : scalar
  end
  if (1) begin : \bracket[7]
  end
  initial begin
    $check_gen_index;
    $finish(0);
  end
endmodule
