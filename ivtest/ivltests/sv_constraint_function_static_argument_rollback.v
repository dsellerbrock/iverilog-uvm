class C;
 static rand int y;
 rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c {y==9; x==f(y);}
endclass
module test;
 C c; int ok;
 initial begin
 c=new; C::y=2; c.x=37;
 ok=c.randomize() with {x==99;};
 if(ok!=0 || C::y!==2 || c.x!==37)
   $fatal(1,"static staged rollback ok=%0d y=%0d x=%0d",ok,C::y,c.x);
 ok=c.randomize();
 if(ok!=1 || C::y!==9 || c.x!==10)
   $fatal(1,"static staged success ok=%0d y=%0d x=%0d",ok,C::y,c.x);
 $display("PASSED");
 end
endmodule
