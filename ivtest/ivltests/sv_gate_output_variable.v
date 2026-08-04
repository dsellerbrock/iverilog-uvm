module main;
  logic a, b, q;
  buf #(1, 1) b1 (q, (a && b));
  initial begin
    a = 1; b = 1; #3;
    if (q !== 1'b1) begin $display("FAILED q=%b", q); $finish; end
    b = 0; #3;
    if (q !== 1'b0) begin $display("FAILED q=%b", q); $finish; end
    $display("PASSED");
  end
endmodule
