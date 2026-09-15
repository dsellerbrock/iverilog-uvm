class C;
 static rand int y;
 rand int x;
 function int f(input int v); return v+1; endfunction
 constraint c {y==9; x==f(y);}
endclass
module test;
 C c; int ok; int changes;
 always @(C::y) changes++;
 initial begin
 c=new; C::y=2; #1; changes=0;
 ok=c.randomize() with {x==99;};
 #1;
 if(ok!=0 || C::y!==2 || changes!=0)
   $fatal(1,"failed solve published static state y=%0d changes=%0d",C::y,changes);
 ok=c.randomize(); #1;
 if(ok!=1 || C::y!==9 || c.x!==10 || changes!=1)
   $fatal(1,"successful static commit y=%0d x=%0d changes=%0d",C::y,c.x,changes);
 $display("PASSED"); $finish(0);
 end
endmodule
