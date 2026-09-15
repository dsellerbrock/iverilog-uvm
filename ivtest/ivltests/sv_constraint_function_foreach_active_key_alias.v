class active_assoc_key;
 rand int bias;
 constraint c {bias==6;}
endclass
class active_assoc_holder;
 rand active_assoc_key child;
 bit entries[active_assoc_key];
 rand int result;
 bit fail;
 constraint c {
 foreach(entries[key]) result==key.bias+1;
 fail -> result==99;
 }
 function new; child=new; endfunction
endclass
module test;
 active_assoc_holder h; int ok;
 initial begin
 h=new; h.child.bias=0; h.entries[h.child]=1;
 ok=h.randomize();
 if(ok!=1 || h.child.bias!=6 || h.result!=7) $fatal(1,"active class key alias");
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.child.bias!=6 || h.result!=7) $fatal(1,"active key rollback");
 $display("PASSED");
 end
endmodule
