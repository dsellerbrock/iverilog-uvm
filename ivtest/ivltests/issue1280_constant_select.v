module top;
  logic [7:0] a [2:1];
  logic s;
  initial begin
    s = 1'b0;
    a[2] = 8'hA5;
    a[1] = 8'h5A;
    #0;
    $probe1280;
    $finish;
  end
endmodule
