class C;
 rand int x;
 int counter;
 function int value(); return $urandom_range(0,3); endfunction
 constraint c {x==value();}
endclass
module test;
 C c;
 initial begin c=new; if(!c.randomize()) $fatal(1,"randomize"); $display("PASSED"); end
endmodule
