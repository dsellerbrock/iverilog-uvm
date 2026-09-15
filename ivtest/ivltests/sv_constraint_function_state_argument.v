// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[7:0] x;
 bit[7:0] wanted;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c { x==f(wanted); }
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.wanted=9; ok=c.randomize();
 if(ok!=1 || c.x!==10) $fatal(1,"state argument x=%0d",c.x);
 c.wanted=19; ok=c.randomize();
 if(ok!=1 || c.x!==20) $fatal(1,"stale state argument x=%0d",c.x);
 $display("PASSED");
 end
endmodule
