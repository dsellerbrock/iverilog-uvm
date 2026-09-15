// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[127:0] wide_value;
 rand int signed_value;
 bit[127:0] wanted;
 int signed_wanted;
 function bit[127:0] wide_state(); return wanted; endfunction
 function int signed_state(); return signed_wanted; endfunction
 constraint c { wide_value==wide_state(); signed_value==signed_state(); }
endclass
module test;
 C c; int ok;
 initial begin
 c=new; c.wanted=(128'b1<<100)|128'h12345678; c.signed_wanted=-17;
 ok=c.randomize();
 if(ok!=1 || c.wide_value!==c.wanted || c.signed_value!==-17)
 $fatal(1,"typed state mismatch wide=%h signed=%d",c.wide_value,c.signed_value);
 c.wanted=128'hffffffffffffffffffffffffffffffff; c.signed_wanted=23;
 ok=c.randomize();
 if(ok!=1 || c.wide_value!==c.wanted || c.signed_value!==23)
 $fatal(1,"typed state changed mismatch");
 $display("PASSED");
 end
endmodule
