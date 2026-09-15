class C;
 rand int x;
 int counter;
 virtual function int value(); return 3; endfunction
 constraint c {x==value();}
endclass
class D extends C;
 virtual function int value(); counter++; return 4; endfunction
endclass
module test; D c; initial begin c=new; if(!c.randomize()) $fatal(1,"randomize"); end endmodule
