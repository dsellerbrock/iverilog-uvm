class selected_method_leaf;
 int x;
 selected_method_leaf other;
 function selected_method_leaf choose(); x=x+1; return other; endfunction
endclass
class selected_method_holder;
 rand selected_method_leaf q[2][1];
 rand int n;
 bit fail;
 constraint c {
 n==(q.find(row) with(row[0].choose().x>5)).size();
 fail -> n==3;
 }
 function new; foreach(q[i,j]) q[i][j]=new; endfunction
endclass
module test;
 selected_method_holder h; selected_method_leaf a,b; int ok;
 initial begin
 h=new; a=new; b=new; a.x=7; b.x=0;
 h.q[0][0].other=a; h.q[1][0].other=b;
 ok=h.randomize();
 if(ok!=1 || h.n!=1) $fatal(1,"selected method receiver");
 b.x=9; ok=h.randomize();
 if(ok!=1 || h.n!=2) $fatal(1,"selected method fresh state");
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.n!=2) $fatal(1,"selected method rollback");
 $display("PASSED");
 end
endmodule
