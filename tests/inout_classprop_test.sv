// Test inout arg writeback to class property — minimal repro of the
// uvm_config_db#(T)::get pattern.
class my_obj;
   int data;
endclass

class container;
   my_obj o;
endclass

class wrapper;
   static function bit fill(inout my_obj v);
      v = new();
      v.data = 42;
      return 1;
   endfunction
endclass

module top;
   container c;
   initial begin
      c = new();
      if (!wrapper::fill(c.o)) $display("FAIL: fill returned 0");
      else if (c.o == null) $display("FAIL: c.o is null after fill");
      else if (c.o.data != 42) $display("FAIL: c.o.data=%0d", c.o.data);
      else $display("INOUT CLASSPROP: PASS");
      $finish;
   end
endmodule
