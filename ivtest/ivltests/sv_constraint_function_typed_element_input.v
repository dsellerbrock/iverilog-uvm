class C;
  rand int a[2];
 rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c {a[1]==9; x==f(a[1]); x==a[0];}
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.a[0]=31; c.a[1]=42; c.x=37;
 ok=c.randomize();
 if(ok!=1 || c.a[1]!==9 || c.a[0]!==10 || c.x!==10)
 $fatal(1,"element priority ok=%0d a0=%0d a1=%0d x=%0d",ok,c.a[0],c.a[1],c.x);
 c.a[0]=31; c.a[1]=42; c.x=37;
 ok=c.randomize() with {x==99;};
 if(ok!=0 || c.a[0]!==31 || c.a[1]!==42 || c.x!==37)
 $fatal(1,"element rollback ok=%0d a0=%0d a1=%0d x=%0d",ok,c.a[0],c.a[1],c.x);
 $display("PASSED"); end
endmodule
