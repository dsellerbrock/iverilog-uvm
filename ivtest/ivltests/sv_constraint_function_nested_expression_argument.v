class C;
 rand int x,y;
 function int g(input int v); return v*2; endfunction
 function int f(input int v); return v+3; endfunction
 constraint c {y==9; x==f(g(y)+1);}
endclass
module test; C c; int ok;
 initial begin c=new; c.y=2; ok=c.randomize();
 if(ok!=1 || c.y!=9 || c.x!=22) $fatal(1,"nested argument dependencies");
 $display("PASSED"); end
endmodule
