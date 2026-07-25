module top;
  int asc[3:10];
  int d[];
  initial begin
    foreach (asc[i]) asc[i] = i;
    d = asc;                     // fixed -> dynamic assignment
    $display("d.size=%0d d[0]=%0d d[7]=%0d", d.size(), d[0], d[7]);
    $finish(0);
  end
endmodule
