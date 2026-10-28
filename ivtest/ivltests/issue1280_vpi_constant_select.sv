module top;
  logic scalar;
  logic [7:0] a [2:1];

  initial begin
    scalar = 1'b1;
    a[2] = 8'hA5;
    a[1] = 8'h5A;
    #0;
    $probe_constant_select;
    $finish;
  end
endmodule
