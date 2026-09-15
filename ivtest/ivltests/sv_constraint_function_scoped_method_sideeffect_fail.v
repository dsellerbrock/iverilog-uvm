class scoped_method_leaf;
 int x;
 scoped_method_leaf other;
 function scoped_method_leaf choose(); x=x+1; return other; endfunction
endclass
class scoped_method_box #(type T=scoped_method_leaf);
 static T obj;
endclass
class scoped_method_holder;
 rand int n;
 bit fail;
 constraint c {
 n==scoped_method_box#(scoped_method_leaf)::obj.choose().x;
 fail -> n==99;
 }
endclass
module test;
 scoped_method_holder h; scoped_method_leaf a,b; int ok;
 initial begin
 h=new; a=new; b=new; a.x=2; b.x=7; a.other=b;
 scoped_method_box#(scoped_method_leaf)::obj=a;
 ok=h.randomize();
 if(ok!=1 || h.n!=7) $fatal(1,"specialized static method return");
 b.x=12; ok=h.randomize();
 if(ok!=1 || h.n!=12) $fatal(1,"specialized method refreshed state");
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.n!=12) $fatal(1,"specialized method rollback");
 $display("PASSED");
 end
endmodule
