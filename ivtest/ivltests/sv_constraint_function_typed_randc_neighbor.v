class C;
 rand int y,x;
 randc bit[1:0] a[2];
 function int f(input int v); return v+1; endfunction
 constraint c {y==9; x==f(y);}
endclass
module test;
 C c; int ok; bit[3:0] seen0,seen1;
 initial begin c=new;
 for(int i=0;i<4;i++) begin
 ok=c.randomize();
 if(ok!=1 || c.x!==10 || seen0[c.a[0]] || seen1[c.a[1]])
 $fatal(1,"randc neighbor lost cycle i=%0d a0=%0d a1=%0d",i,c.a[0],c.a[1]);
 seen0[c.a[0]]=1; seen1[c.a[1]]=1;
 end
 if(seen0!==4'b1111 || seen1!==4'b1111) $fatal(1,"randc incomplete");
 $display("PASSED"); end
endmodule
