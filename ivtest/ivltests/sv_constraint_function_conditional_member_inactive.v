class conditional_guard_leaf;
 int value;
endclass
class conditional_guard_holder;
 rand bit pick;
 rand int result;
 conditional_guard_leaf a,b;
 bit enable;
 constraint c {
 result==(enable ? (pick?a:b).value : 13);
 }
endclass
module test;
 conditional_guard_holder h; int ok;
 initial begin
 h=new; h.b=new; h.b.value=7; h.a=null; h.enable=0;
 ok=h.randomize() with {pick==1; result==13;};
 if(ok!=1 || h.pick!=1 || h.result!=13) $fatal(1,"disabled conditional must not constrain selector");
 h.enable=1;
 ok=h.randomize() with {pick==0;};
 if(ok!=1 || h.result!=7) $fatal(1,"unselected null handle");
 $display("PASSED");
 end
endmodule
