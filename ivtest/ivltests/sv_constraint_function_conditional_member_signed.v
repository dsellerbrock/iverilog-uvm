class conditional_signed_leaf;
 int value;
endclass
class conditional_signed_holder;
 conditional_signed_leaf a,b;
 rand bit pick;
 rand int result;
 constraint c {
 (pick?a:b).value < 0;
 result==(pick?a:b).value;
 }
endclass
module test;
 conditional_signed_holder h; int ok;
 initial begin
 h=new; h.a=new; h.b=new; h.a.value=-3; h.b.value=7;
 ok=h.randomize();
 if(ok!=1 || h.pick!=1 || h.result!=-3) $fatal(1,"conditional signed comparison");
 ok=h.randomize() with {result==7;};
 if(ok!=0 || h.pick!=1 || h.result!=-3) $fatal(1,"conditional signed rollback");
 $display("PASSED");
 end
endmodule
