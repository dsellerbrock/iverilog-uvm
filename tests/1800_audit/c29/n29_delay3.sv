primitive inv(y, a);
  output y;
  input a;
  table
    0 : 1;
    1 : 0;
  endtable
endprimitive

module n29_delay3;
  reg a = 0;
  wire y;
  inv #(1, 2, 3) u(y, a);
endmodule
