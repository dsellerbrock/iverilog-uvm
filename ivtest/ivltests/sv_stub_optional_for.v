module test;
  integer i;
  initial begin
    i = 0;
    for (; i < 2; i++) begin end
    for (i = 0; i < 2;) i++;
    for (;;) break;
  end
endmodule
