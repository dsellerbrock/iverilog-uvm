module m;
  generate
    if (1) begin : g1
      assign implicit_net = 1'b1;
    end
    if (1) begin : g2
      assign implicit_net = 1'b0;
    end
  endgenerate

  initial begin
    #1;
    if (g1.implicit_net !== 1'b1 || g2.implicit_net !== 1'b0)
      $fatal(1, "generate-scope implicit nets are not distinct");
    $display("PASS: distinct generate-scope implicit nets");
  end
endmodule
