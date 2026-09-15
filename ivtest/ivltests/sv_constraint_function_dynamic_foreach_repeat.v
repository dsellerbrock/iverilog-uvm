class C;
 rand int q[$]; rand int x; int wanted;
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==wanted; q[1]==9; x==f(q[1]); foreach(q[i]) if(i!=1) q[i]==x;}
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.q.push_back(31); c.x=37; c.wanted=3;
 ok=c.randomize() with {x==99;};
 if(ok!=0 || c.q.size()!=1 || c.q[0]!==31 || c.x!==37)
 $fatal(1,"growth rollback ok=%0d size=%0d x=%0d",ok,c.q.size(),c.x);
 ok=c.randomize();
 if(ok!=1 || c.q.size()!=3 || c.q[0]!==10 || c.q[1]!==9 || c.q[2]!==10 || c.x!==10)
 $fatal(1,"growth success");
 c.wanted=2; ok=c.randomize();
 if(ok!=1 || c.q.size()!=2 || c.q[0]!==10 || c.q[1]!==9 || c.x!==10)
 $fatal(1,"shrink success");
 c.wanted=4; ok=c.randomize() with {x==99;};
 if(ok!=0 || c.q.size()!=2 || c.q[0]!==10 || c.q[1]!==9 || c.x!==10)
 $fatal(1,"repeat growth rollback");
 $display("PASSED"); end
endmodule
