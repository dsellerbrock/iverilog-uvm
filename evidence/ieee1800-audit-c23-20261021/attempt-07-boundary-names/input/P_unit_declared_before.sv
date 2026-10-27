bit b = 1;
task t;
  int x;
  int y;
  x = b;
  y = $unit::b;
  $display("%0d %0d", x, y);
endtask
module m;
  initial t();
endmodule
