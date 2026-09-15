class C;
 rand int q[$]; rand int x;
 function int f(input int a,input int b); return a+b; endfunction
 constraint c { q.size()==3; x==f(q[0],q[2]);
   foreach(q[i]) if(i==0) q[i]==8; else if(i==2) q[i]==9; else q[i]==x; }
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.x=37; ok=c.randomize();
 if(ok!=1 || c.q.size()!=3 || c.x!==17 || c.q[0]!==8 || c.q[1]!==17 || c.q[2]!==9)
   $fatal(1,"multiple foreach arguments ok=%0d x=%0d",ok,c.x);
 ok=c.randomize() with{x==99;};
 if(ok!=0 || c.q.size()!=3 || c.x!==17 || c.q[0]!==8 || c.q[1]!==17 || c.q[2]!==9)
   $fatal(1,"multiple foreach argument rollback");
 $display("PASSED"); end
endmodule
