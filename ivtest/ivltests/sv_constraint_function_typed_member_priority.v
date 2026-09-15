class C;
 typedef struct {rand int a; rand int b;} pair_t;
 rand pair_t s;
 rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c {s.b==9; x==f(s.b); s.a==x;}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.s.a=31; c.s.b=42; c.x=37;
 ok=c.randomize();
 if(ok!=1 || c.s.b!==9 || c.s.a!==10 || c.x!==10)
 $fatal(1,"member priority ok=%0d a=%0d b=%0d x=%0d",ok,c.s.a,c.s.b,c.x);
 $display("PASSED"); end
endmodule
