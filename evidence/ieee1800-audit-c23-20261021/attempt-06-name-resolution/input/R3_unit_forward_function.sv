task t;
  int x;
  x = f(1);
  $display("%0d", x);
endtask
function int f(int y);
  return y + 1;
endfunction
module top;
  initial t();
endmodule
