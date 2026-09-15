class assoc_key;
 int bias;
endclass
class assoc_value;
 bit dummy;
endclass
class assoc_key_holder;
 assoc_value entries[assoc_key];
 rand int result;
 int key;
 bit fail;
 constraint c {
   foreach(entries[key]) result == key.bias + 1;
   fail -> result == 99;
 }
endclass
module test;
 assoc_key_holder h; assoc_key k, second; assoc_value v; int ok;
 initial begin
 h=new; k=new; v=new; k.bias=6; h.key=100; h.entries[k]=v;
 ok=h.randomize();
 if(ok!=1 || h.result!=7 || h.key!=100) $fatal(1,"class key member");
 k.bias=12; ok=h.randomize();
 if(ok!=1 || h.result!=13) $fatal(1,"class key refreshed state");
 second=new; second.bias=5; h.entries[second]=v;
 ok=h.randomize();
 if(ok!=0 || h.result!=13) $fatal(1,"all class keys must constrain");
 h.entries.delete(second);
 h.fail=1; ok=h.randomize();
 if(ok!=0 || h.result!=13 || k.bias!=12) $fatal(1,"class key rollback");
 h.entries.delete(k); ok=h.randomize();
 if(ok!=1 || h.result!=99) $fatal(1,"empty class-key map must be vacuous");
 $display("PASSED");
 end
endmodule
