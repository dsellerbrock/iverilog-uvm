class C;
 rand int x;
 int counter;
 function int helper(); counter++; return 3; endfunction
 function int value(); return helper(); endfunction
 constraint c {x==value();}
endclass
module test;
 C c;
 initial begin c=new; if(!c.randomize()) $fatal(1,"randomize"); $display("PASSED"); end
endmodule
