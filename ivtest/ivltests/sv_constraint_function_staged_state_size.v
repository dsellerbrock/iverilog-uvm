class C;
 rand bit[7:0] x,y;
 int q[$];
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c {y==9; x==f(y); q.size()==0;}
endclass
module test;
 C c; int ok;
 initial begin c=new;
 ok=c.randomize(); if(ok!=1 || c.x!==10 || c.y!==9) $fatal(1,"state constraint with staged call");
 c.q.push_back(7);
 c.x=37; c.y=42; ok=c.randomize(); if(ok!=0 || c.x!==37 || c.y!==42) $fatal(1,"state check dropped or failed rollback");
 $display("PASSED"); end
endmodule
