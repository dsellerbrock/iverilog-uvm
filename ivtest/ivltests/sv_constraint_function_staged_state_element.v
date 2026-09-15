class C;
 rand bit[7:0] x,y;
 int q[$];
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c {y==9; x==f(y); q[0]==7;}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.q.push_back(7);
 ok=c.randomize(); if(ok!=1 || c.x!==10 || c.y!==9) $fatal(1,"state constraint with staged call");
 c.q[0]=8;
 c.x=37; c.y=42; ok=c.randomize(); if(ok!=0 || c.x!==37 || c.y!==42) $fatal(1,"state check dropped or failed rollback ok=%0d x=%0d y=%0d q0=%0d",ok,c.x,c.y,c.q[0]);
 $display("PASSED"); end
endmodule
