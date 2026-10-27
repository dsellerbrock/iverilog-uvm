class O;
  extern function int f(int a);
  extern task t(int a);
endclass

function int O::f(int a, int b);
  return a + b;
endfunction

task O::t(int a, int b);
endtask

module main;
endmodule
