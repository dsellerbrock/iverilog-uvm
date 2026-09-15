class conditional_base;
 int value;
endclass
class conditional_derived extends conditional_base;
 randc bit [7:0] value;
endclass
class conditional_holder;
 rand bit pick;
 rand int result;
 conditional_base a;
 conditional_derived b;
 bit fail;
 constraint c {
 result == (pick ? b : a).value;
 fail -> result==99;
 }
endclass
module test;
 conditional_holder h; conditional_base view_b; int ok;
 initial begin
 h=new; h.a=new; h.b=new; view_b=h.b;
 h.a.value=3; view_b.value=7; h.b.value=19;
 ok=h.randomize() with {result==7;};
 if(ok!=1 || h.pick!=1 || h.result!=7 || h.b.value!=19) $fatal(1,"conditional static member type");
 repeat(8) begin
   ok=h.randomize() with {result==3;};
   if(ok!=1 || h.pick!=0 || h.result!=3) $fatal(1,"result must choose base handle");
   ok=h.randomize() with {result==7;};
   if(ok!=1 || h.pick!=1 || h.result!=7) $fatal(1,"result must choose derived handle");
 end
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.result!=7 || h.b.value!=19) $fatal(1,"conditional member rollback");
 $display("PASSED");
 end
endmodule
