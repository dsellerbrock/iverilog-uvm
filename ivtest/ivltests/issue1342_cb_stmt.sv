module top;
  integer x;
  integer i;

  initial begin
    x = 1;
    #1 x = 2;
    i = 0;
    while (i < 2) i = i + 1;
    $finish;
  end
endmodule
