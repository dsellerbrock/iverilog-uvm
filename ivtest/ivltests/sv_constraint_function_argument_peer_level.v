class C;
 rand bit[7:0] x,y,z;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c {y==9; x==f(y); x==z;}
endclass
module test;
 C c; int ok;
 initial begin c=new; ok=c.randomize();
 if(ok!=1 || c.y!==9 || c.x!==10 || c.z!==10) $fatal(1,"ordinary peer solved too early");
 $display("PASSED"); end
endmodule
