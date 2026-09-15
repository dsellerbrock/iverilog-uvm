// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: functions in constraints.
class C;
 rand bit[7:0] x,y;
 function bit[7:0] f(input bit[7:0] v); return v+1; endfunction
 constraint c {x==f(y);}
endclass
module test;
 C c; int ok; int wanted;
 initial begin c=new; wanted=23;
 ok=c.randomize() with {y==local::wanted;};
 if(ok!=1 || c.y!==23 || c.x!==24) $fatal(1,"inline priority");
 wanted=41; ok=c.randomize() with {y==local::wanted;};
 if(ok!=1 || c.y!==41 || c.x!==42) $fatal(1,"inline retry capture");
 $display("PASSED"); end
endmodule
