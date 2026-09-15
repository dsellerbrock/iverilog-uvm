class C;
 rand int q[$]; rand int x,y,z;
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==2; q[0]==9; q[1]==11; z==q[0]+1; y==9; x==f(y);}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.q.push_back(42); c.z=37;
 ok=c.randomize();
 if(ok!=1 || c.q.size()!=2 || c.q[0]!==9 || c.q[1]!==11 || c.z!==10 || c.x!==10)
 $fatal(1,"dynamic unordered peers ok=%0d x=%0d z=%0d",ok,c.x,c.z);
 $display("PASSED"); end
endmodule
