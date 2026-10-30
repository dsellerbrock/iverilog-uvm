module tri1_source(output tri1 o);
endmodule

module tri0_source(output tri0 o);
endmodule

module tb;
  logic tri1_value;
  logic tri0_value;

  tri1_source u1(tri1_value);
  tri0_source u0(tri0_value);

  initial begin
    #1;
    if (tri1_value !== 1'b1 || tri0_value !== 1'b0)
      $fatal(1, "tri1=%b tri0=%b", tri1_value, tri0_value);
    $display("PASS");
  end
endmodule
