class C;
 rand int x;
 function int value(); static int counter=0; counter++; return counter; endfunction
 constraint c {x==value();}
endclass
module test; C c; initial begin c=new; if(!c.randomize()) $fatal(1,"randomize"); end endmodule
