primitive p(q, a, b);
  output reg q;
  input a, b;
  table
    (01) (10) : ? : 1;
    r f : ? : 1;
    * (0?) : ? : 1;
    0 p : ? : 1;
    n 1 : ? : 0;
  endtable
endprimitive
module top; wire q; reg a, b; p inst(q, a, b); endmodule
