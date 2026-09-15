class locator_count;
 rand int a[4]; rand int n;
 constraint c {a[0]==2; a[1]==7; a[2]==9; a[3]==4;
   n==(a.find(i) with(i>5)).size();}
endclass
module test;
 locator_count c; int ok;
 initial begin
 c=new; c.n=37;
 c.a[0]=31; c.a[1]=32; c.a[2]=33; c.a[3]=34;
 ok=c.randomize();
 if(ok!=1 || c.n!=2 || c.a[0]!=2 || c.a[1]!=7 || c.a[2]!=9 || c.a[3]!=4)
   $fatal(1,"fixed locator count ok=%0d n=%0d",ok,c.n);
 ok=c.randomize() with {n==3;};
 if(ok!=0 || c.n!=2 || c.a[0]!=2 || c.a[1]!=7 || c.a[2]!=9 || c.a[3]!=4)
   $fatal(1,"fixed locator count rollback");
 $display("PASSED");end
endmodule
