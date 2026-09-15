class conditional_rhs_leaf;
 int value;
endclass
class conditional_rhs_holder;
 conditional_rhs_leaf a,b;
 rand bit pick, yes_result, no_result;
 bit yes_guard, no_guard;
 constraint c {
 yes_result==(((pick?a:b).value==0)||yes_guard);
 no_result==(((pick?a:b).value==0)&&no_guard);
 }
endclass
module test;
 conditional_rhs_holder h; int ok;
 initial begin
 h=new; h.a=null; h.b=new; h.b.value=7;
 h.yes_guard=1; h.no_guard=0;
 ok=h.randomize() with {pick==1;};
 if(ok!=1 || h.pick!=1 || h.yes_result!=1 || h.no_result!=0)
   $fatal(1,"deciding right state guards");
 $display("PASSED");
 end
endmodule
