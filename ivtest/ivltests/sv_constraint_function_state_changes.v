// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit [7:0] x;
 bit [7:0] wanted;
 function bit [7:0] state_value();return wanted;endfunction
 constraint c { x == state_value(); }
endclass
module test;
 C obj;int ok;
 initial begin obj=new;
 obj.wanted=8'd3;ok=obj.randomize();if(ok!=1 || obj.x!==3)$fatal(1,"state3 x=%d ok=%d",obj.x,ok);
 obj.wanted=8'd9;ok=obj.randomize();if(ok!=1 || obj.x!==9)$fatal(1,"state9 x=%d ok=%d",obj.x,ok);
 $display("PASSED");end
endmodule
