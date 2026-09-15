class C;
 static rand bit[31:0] y;
 rand bit[7:0] x;
 function bit[7:0] f(const ref bit[7:0] v); return v; endfunction
 constraint c {y==32'h12345678; x==f(y[15:8]);}
endclass
module test;
 C c; int ok;
 initial begin c=new; C::y=0; ok=c.randomize();
 if(ok!=1 || C::y!==32'h12345678 || c.x!==8'h56)
   $fatal(1,"selected static ref y=%h x=%h",C::y,c.x);
 $display("PASSED"); end
endmodule
