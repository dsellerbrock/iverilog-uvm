class locator_active_leaf;
 rand int x;
 constraint c { x inside {[0:9]}; }
endclass
class locator_active_holder;
 rand locator_active_leaf q[2];
 rand int n;
 constraint c { n == 2; n == (q.find(i) with (i.x > 5)).size(); }
 function new; foreach(q[i]) q[i]=new; endfunction
endclass
module test;
 locator_active_holder h; int ok; int a,b;
 initial begin
 h=new; h.q[0].x=0; h.q[1].x=0;
 ok=h.randomize();
 if(ok!=1 || h.n!=2 || h.q[0].x<=5 || h.q[1].x<=5)
   $fatal(1,"active child locator");
 a=h.q[0].x; b=h.q[1].x;
 ok=h.randomize() with {n==0;};
 if(ok!=0 || h.n!=2 || h.q[0].x!=a || h.q[1].x!=b)
   $fatal(1,"active child rollback");
 $display("PASSED");
 end
endmodule
