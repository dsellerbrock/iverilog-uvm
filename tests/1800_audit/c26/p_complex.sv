package ComplexPkg;
  typedef struct {shortreal i, r;} Complex;
  function Complex add(Complex a, b);
    add.r = a.r + b.r;
    add.i = a.i + b.i;
  endfunction
endpackage : ComplexPkg
module top;
  ComplexPkg::Complex a, b, c;
  initial begin
    a.r = 1; a.i = 2; b.r = 3; b.i = 4;
    c = ComplexPkg::add(a, b);
    $display("P9 %0d %0d", int'(c.r), int'(c.i));
  end
endmodule
