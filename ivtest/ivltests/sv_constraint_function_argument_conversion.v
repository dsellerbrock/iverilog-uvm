// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand int x;
 int state_value;
 function int narrowed(input byte signed v); return v; endfunction
 constraint c {x==narrowed(state_value);}
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.state_value=511;
 if(c.narrowed(c.state_value)!==-1) $fatal(1,"ordinary argument conversion");
 ok=c.randomize(); if(ok!=1 || c.x!==-1) $fatal(1,"constraint argument conversion x=%0d",c.x);
 c.state_value=258;
 ok=c.randomize(); if(ok!=1 || c.x!==2) $fatal(1,"changed converted argument x=%0d",c.x);
 $display("PASSED"); end
endmodule
