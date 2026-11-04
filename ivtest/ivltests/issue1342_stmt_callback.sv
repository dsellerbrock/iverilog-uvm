module top;
  integer x;
  integer i;
  initial begin
    x = 1;
    #1 x = 2;
    i = 0;
    do i = i + 1; while (i < 2);
    repeat (2) i = i + 1;
    while (i < 6) i = i + 1;
    for (i = 0; i < 2; i = i + 1) x = x + 1;
    $finish;
  end
endmodule
