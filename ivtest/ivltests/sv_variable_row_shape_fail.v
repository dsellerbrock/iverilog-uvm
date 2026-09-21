module main;
  int a[0:1][0:2];
  int b[0:1][0:3];
  int i;
  initial begin
    i = 0;
    a[i] = b[1];
  end
endmodule
