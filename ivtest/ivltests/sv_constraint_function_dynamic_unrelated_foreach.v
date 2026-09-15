class C;
 rand int q[$], r[$]; rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c { q.size()==2; r.size()==3; q[1]==9;
   x==f(q[1]); q[0]==x; foreach(r[i]) r[i]==5; }
endclass
module test;
 C c; int ok;
 initial begin
 c=new; ok=c.randomize();
 if(ok!=1 || c.x!==10 || c.q.size()!=2 || c.r.size()!=3)
   $fatal(1,"unrelated foreach failed ok=%0d",ok);
 if(c.q[0]!==10 || c.q[1]!==9) $fatal(1,"argument priority failed");
 foreach(c.r[i]) if(c.r[i]!==5) $fatal(1,"unrelated foreach dropped");
 $display("PASSED");
 end
endmodule
