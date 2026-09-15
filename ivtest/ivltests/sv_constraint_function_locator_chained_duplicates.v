class locator_duplicate_leaf;
 rand int x;
 constraint c {x==7;}
endclass
class locator_duplicate_holder;
 rand locator_duplicate_leaf q[3];
 rand int n;
 bit fail;
 constraint c {
 n==((q.find(i) with(i.x>5)).find(j) with(j.x<9)).size();
 fail -> n==1;
 }
endclass
module test;
 locator_duplicate_holder h; locator_duplicate_leaf leaf; int ok;
 initial begin
 h=new; leaf=new; leaf.x=0; foreach(h.q[i]) h.q[i]=leaf;
 ok=h.randomize();
 if(ok!=1 || h.n!=3 || leaf.x!=7) $fatal(1,"count repeated occurrences");
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.n!=3 || leaf.x!=7 || h.q[0]!=h.q[2])
   $fatal(1,"duplicate alias rollback");
 $display("PASSED");
 end
endmodule
