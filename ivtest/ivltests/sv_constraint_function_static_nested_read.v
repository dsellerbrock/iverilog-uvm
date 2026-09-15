class C;
 static rand int y;
 rand int x;
 function int helper(); return y+1; endfunction
 function int f(input int v); return helper()+v; endfunction
 constraint c {y==9; x==f(y);}
endclass
module test;
 C c; int ok;
 initial begin c=new; C::y=2; ok=c.randomize();
 if(ok!=1 || C::y!==9 || c.x!==19)
   $fatal(1,"nested static read y=%0d x=%0d",C::y,c.x);
 $display("PASSED"); end
endmodule
