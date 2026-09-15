class C;
 rand bit[7:0] x,y,z;
 function bit[7:0] f(input bit[7:0] a,b); return a+b; endfunction
 constraint c {y==9; z==y+1; x+y==f(y,z);}
endclass
module test;
 C c; int ok;
 initial begin c=new; ok=c.randomize();
 if(ok!=1 || c.y!==9 || c.z!==10 || c.x!==10) $fatal(1,"function arguments split into unequal priorities");
 $display("PASSED"); end
endmodule
