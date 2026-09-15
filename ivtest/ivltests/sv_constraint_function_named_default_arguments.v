class C;
 rand int x,y; int state_value;
 function int f(input int a=4,input int b=7); return a*10+b; endfunction
 constraint c {x==f(.b(state_value)); y==f();}
endclass
module test; C c; int ok;
 initial begin c=new; c.state_value=9; ok=c.randomize();
 if(ok!=1 || c.x!=49 || c.y!=47) $fatal(1,"named and default arguments");
 $display("PASSED"); end
endmodule
