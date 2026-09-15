class C;
 rand int q[$]; rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==2; foreach(q[i]) q[i]==9; x==f(q[1]);}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.q.push_back(42); c.x=37;
 ok=c.randomize();
 if(ok!=1 || c.q.size()!=2 || c.q[0]!==9 || c.q[1]!==9 || c.x!==10)
 $fatal(1,"foreach argument priority ok=%0d size=%0d x=%0d",ok,c.q.size(),c.x);
 $display("PASSED"); end
endmodule
