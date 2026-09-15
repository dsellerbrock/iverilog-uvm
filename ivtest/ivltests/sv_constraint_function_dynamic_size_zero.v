class C;
 rand int q[$]; rand int x; int wanted;
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==wanted; x==f(q.size()); foreach(q[i]) q[i]==x;}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.wanted=0;
 ok=c.randomize(); if(ok!=1 || c.q.size()!=0 || c.x!==1) $fatal(1,"default empty");
 c.q.push_back(31);
 ok=c.randomize(); if(ok!=1 || c.q.size()!=0 || c.x!==1) $fatal(1,"zero size");
 c.wanted=2; ok=c.randomize();
 if(ok!=1 || c.q.size()!=2 || c.q[0]!==3 || c.q[1]!==3 || c.x!==3) $fatal(1,"growth from zero");
 c.wanted=0; ok=c.randomize() with {x==99;};
 if(ok!=0 || c.q.size()!=2 || c.q[0]!==3 || c.q[1]!==3 || c.x!==3) $fatal(1,"zero rollback");
 $display("PASSED"); end
endmodule
