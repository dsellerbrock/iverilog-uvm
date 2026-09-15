class C;
 rand int q[$]; rand int x; int wanted;
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==wanted; x==f(q.size()); foreach(q[i]) q[i]==x;}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.q.push_back(3); c.q.push_back(3); c.wanted=2; c.q.rand_mode(0);
 ok=c.randomize();
 if(ok!=1 || c.q.size()!=2 || c.q[0]!==3 || c.q[1]!==3 || c.x!==3)
 $fatal(1,"inactive size state");
 c.wanted=3; c.x=37; ok=c.randomize();
 if(ok!=0 || c.q.size()!=2 || c.q[0]!==3 || c.x!==37)
 $fatal(1,"inactive size rollback");
 c.q.rand_mode(1); ok=c.randomize();
 if(ok!=1 || c.q.size()!=3 || c.q[0]!==4 || c.q[1]!==4 || c.q[2]!==4 || c.x!==4)
 $fatal(1,"reenabled size");
 $display("PASSED"); end
endmodule
