typedef int mytype;
function int f();
  mytype x;
  x = 9;
  return x;
endfunction
module m;
  initial $display("%0d", f());
endmodule
