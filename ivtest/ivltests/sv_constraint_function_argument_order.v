// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[7:0] x, y;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c { y==9; x==f(y); }
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.y=2;
 ok=c.randomize();
 if(ok!=1 || c.y!==9 || c.x!==10) $fatal(1,"argument order ok=%0d x=%0d y=%0d",ok,c.x,c.y);
 $display("PASSED");
 end
endmodule
