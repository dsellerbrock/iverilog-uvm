module main;
  int a[2][3];
  initial begin
    foreach (a[1.5][j]) $display("unexpected %0d", j);
  end
endmodule
