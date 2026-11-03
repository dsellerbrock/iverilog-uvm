module top;
  integer x;
  initial begin
    x = 1;
    #1 x = 2;
    $finish;
  end
endmodule
