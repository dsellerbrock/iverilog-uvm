class C;
 rand bit[7:0] x,y;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c {y==9; x==f(y+2);}
endclass
module test; C c; int ok;
 initial begin c=new; c.y=2; ok=c.randomize();
 if(ok!=1 || c.y!==9 || c.x!==12) $fatal(1,"random expression priority");
 $display("PASSED"); end
endmodule
