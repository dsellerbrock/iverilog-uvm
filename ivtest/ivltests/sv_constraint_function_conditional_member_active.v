class conditional_active_leaf;
 rand int value;
endclass
class conditional_active_holder;
 rand conditional_active_leaf a,b;
 rand bit pick;
 rand int result;
 constraint c {
 a.value==3; b.value==7;
 result==(pick?a:b).value;
 }
 function new; a=new; b=new; endfunction
endclass
module test;
 conditional_active_holder h; int ok;
 initial begin
 h=new; h.a.value=0; h.b.value=0;
 repeat(4) begin
 ok=h.randomize() with {result==3;};
 if(ok!=1 || h.pick!=1 || h.result!=3 || h.a.value!=3 || h.b.value!=7)
   $fatal(1,"conditional active true member");
 ok=h.randomize() with {result==7;};
 if(ok!=1 || h.pick!=0 || h.result!=7 || h.a.value!=3 || h.b.value!=7)
   $fatal(1,"conditional active false member");
 end
 ok=h.randomize() with {result==99;};
 if(ok!=0 || h.pick!=0 || h.result!=7 || h.a.value!=3 || h.b.value!=7)
   $fatal(1,"conditional active rollback");
 $display("PASSED");
 end
endmodule
