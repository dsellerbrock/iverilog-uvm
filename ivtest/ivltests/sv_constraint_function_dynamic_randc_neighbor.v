class C;
 rand int x,y; randc bit[1:0] q[$];
 function int f(input int v); return v+1; endfunction
 constraint c {q.size()==2; y==9; x==f(y);}
endclass
module test;
 C c; int ok; int old0,old1; bit[3:0] seen0,seen1;
 initial begin c=new;
 for(int i=0;i<4;i++) begin
 if(i==2) begin
 old0=c.q[0]; old1=c.q[1];
 ok=c.randomize() with {x==99;};
 if(ok!=0 || c.q.size()!=2 || c.q[0]!==old0 || c.q[1]!==old1 || c.x!==10)
 $fatal(1,"dynamic randc failed-call rollback");
 end
 ok=c.randomize();
 if(ok!=1 || c.x!==10 || c.q.size()!=2 || seen0[c.q[0]] || seen1[c.q[1]])
 $fatal(1,"dynamic randc neighbor cycle i=%0d ok=%0d size=%0d",i,ok,c.q.size());
 seen0[c.q[0]]=1; seen1[c.q[1]]=1;
 end
 if(seen0!==4'b1111 || seen1!==4'b1111) $fatal(1,"dynamic randc incomplete");
 $display("PASSED"); end
endmodule
