class C;
 rand int q[$]; rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==2; x==f(q.size()); foreach(q[i]) q[i]==x;}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.q.push_back(42); c.x=37;
 ok=c.randomize();
 if(ok!=1 || c.q.size()!=2 || c.x!==3 || c.q[0]!==3 || c.q[1]!==3)
 $fatal(1,"size priority ok=%0d size=%0d x=%0d",ok,c.q.size(),c.x);
 $display("PASSED"); end
endmodule
