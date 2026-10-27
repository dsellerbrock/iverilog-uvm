function int f();
  mytype x;
  x = 9;
  return x;
endfunction
typedef int mytype;
module m;
  initial $display("%0d", f());
endmodule
