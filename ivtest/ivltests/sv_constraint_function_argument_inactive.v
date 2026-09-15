// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[7:0] x,y;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c {x==f(y);}
endclass
module test;
 C c; int ok;
 initial begin c=new; c.y=17; c.y.rand_mode(0); ok=c.randomize();
 if(ok!=1 || c.y!==17 || c.x!==18) $fatal(1,"inactive argument is state");
 c.y=29; c.y.rand_mode(1); ok=c.randomize(x);
 if(ok!=1 || c.y!==29 || c.x!==30) $fatal(1,"unselected argument is state");
 $display("PASSED"); end
endmodule
