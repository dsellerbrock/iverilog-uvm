class C;
 rand int x; int state_value;
 function int f(input int v); return v+1; endfunction
 constraint c {x==f(state_value+2);}
endclass
module test; C c; int ok;
 initial begin c=new; c.state_value=9; ok=c.randomize();
 if(ok!=1 || c.x!=12) $fatal(1,"state expression argument");
 c.state_value=16; ok=c.randomize(); if(ok!=1 || c.x!=19) $fatal(1,"changed state expression");
 $display("PASSED"); end
endmodule
