class noarg_method_leaf;
 rand bit pick;
 int x;
 noarg_method_leaf first_choice, second_choice;
 constraint c {pick==1;}
 function noarg_method_leaf choose();
   if(pick) return second_choice;
   return first_choice;
 endfunction
endclass
class noarg_method_holder;
 rand noarg_method_leaf q[2][1];
 rand int n;
 bit fail;
 constraint c {
 n==(q.find(row) with(row[0].choose().x>5)).size();
 fail -> n==3;
 }
 function new; foreach(q[i,j]) q[i][j]=new; endfunction
endclass
module test;
 noarg_method_holder h; noarg_method_leaf a,b; int ok;
 initial begin
 h=new; a=new; b=new; a.x=7; b.x=0;
 foreach(h.q[i,j]) begin
   h.q[i][j].pick=0; h.q[i][j].first_choice=a; h.q[i][j].second_choice=b;
 end
 ok=h.randomize();
 if(ok!=1 || h.n!=2 || h.q[0][0].pick!=1 || h.q[1][0].pick!=1)
   $fatal(1,"noarg method must sample pre-solve body state");
 ok=h.randomize();
 if(ok!=1 || h.n!=0) $fatal(1,"noarg method refreshed state");
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.n!=0 || h.q[0][0].pick!=1) $fatal(1,"noarg method rollback");
 $display("PASSED");
 end
endmodule
