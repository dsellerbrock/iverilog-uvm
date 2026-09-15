// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit negative;
 bit signed [127:0] wanted;
 function bit signed [127:0] value(); return wanted; endfunction
 constraint c {negative == (value() < 0);}
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.wanted=-(128'sb1 << 100);
 ok=c.randomize(); if(ok!=1 || c.negative!==1) $fatal(1,"wide negative sign lost");
 c.wanted=128'sb1 << 100;
 ok=c.randomize(); if(ok!=1 || c.negative!==0) $fatal(1,"wide positive sign lost");
 $display("PASSED"); end
endmodule
