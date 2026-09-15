class C;
 rand int x; int values[2];
 function int f(const ref int v); return v+1; endfunction
 constraint c {x==f(values[1]);}
endclass
module test; C c; int ok;
 initial begin c=new; c.values[1]=9; ok=c.randomize();
 if(ok!=1 || c.x!=10 || c.values[1]!=9) $fatal(1,"selected const reference");
 $display("PASSED"); end
endmodule
