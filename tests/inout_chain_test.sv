// Test inout chain through 2 functions — uvm_config_db::get pattern.
class my_obj;
   int data;
endclass

class container;
   my_obj o;
endclass

class inner;
   virtual function bit do_get(inout my_obj v);
      v = new();
      v.data = 42;
      return 1;
   endfunction
endclass

class outer;
   static function bit get(inout my_obj v);
      inner imp = new();
      return imp.do_get(v);
   endfunction
endclass

module top;
   container c;
   initial begin
      c = new();
      if (!outer::get(c.o)) $display("FAIL: outer::get returned 0");
      else if (c.o == null) $display("FAIL: c.o is null after chain");
      else if (c.o.data != 42) $display("FAIL: c.o.data=%0d", c.o.data);
      else $display("INOUT CHAIN: PASS");
      $finish;
   end
endmodule
