class C;
 rand int x;
 int wanted;
 function int helper(input int n);
 int s;
 s=0;
 for(int i=0;i<n;i++) begin
 if(i%2==0) s+=i; else s+=1;
 end
 return s;
 endfunction
 function int value(); return helper(wanted); endfunction
 constraint c {x==value();}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.wanted=6; ok=c.randomize();
 if(ok!=1 || c.x!=9) $fatal(1,"pure helper local loop");
 c.wanted=4; ok=c.randomize(); if(ok!=1 || c.x!=4) $fatal(1,"pure helper changed state");
 $display("PASSED"); end
endmodule
