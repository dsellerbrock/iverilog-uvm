class scoped_index_leaf;
 int data[2];
endclass
class scoped_index_store;
 static scoped_index_leaf q[1];
 static int count;
 static function int bump(); count=count+1; return 0; endfunction
endclass
class scoped_index_holder;
 rand int n;
 constraint c {
 n == (scoped_index_store::q.find(item) with
       (item.data[scoped_index_store::bump()] == 0)).size();
 }
endclass
module test;
 scoped_index_holder h;
 initial begin h=new; end
endmodule
