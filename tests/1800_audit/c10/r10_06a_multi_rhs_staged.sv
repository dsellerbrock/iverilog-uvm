module r10_06a_multi_rhs_staged;
  logic a, b, c, d;
  initial begin
    assign d = a & b & c;
    a = 1; #1;
    b = 0; #1;
    c = 1; #1;
    $display("STAGED d=%b a=%b b=%b c=%b", d, a, b, c);
    $finish;
  end
endmodule
