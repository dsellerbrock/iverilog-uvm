// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand int x;
 int state_value;
 function int val(const ref int v); return v+1; endfunction
 constraint c {x==val(state_value);}
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.state_value=17;
 if(c.val(c.state_value)!==18) $fatal(1,"ordinary const ref control");
 ok=c.randomize(); if(ok!=1 || c.x!==18 || c.state_value!==17) $fatal(1,"const ref constraint x=%0d",c.x);
 $display("PASSED"); end
endmodule
