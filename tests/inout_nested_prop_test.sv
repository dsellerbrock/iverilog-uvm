// Test inout writeback into a NESTED class property: this.cfg.vif
class my_obj;
   int data;
endclass

class my_cfg;
   my_obj o;
endclass

class my_env;
   my_cfg cfg;
endclass

class wrapper;
   static function bit fill(inout my_obj v);
      v = new();
      v.data = 99;
      return 1;
   endfunction
endclass

module top;
   my_env env;
   initial begin
      env = new();
      env.cfg = new();
      if (!wrapper::fill(env.cfg.o)) $display("FAIL: fill returned 0");
      else if (env.cfg.o == null) $display("FAIL: env.cfg.o null after fill");
      else if (env.cfg.o.data != 99) $display("FAIL: data=%0d", env.cfg.o.data);
      else $display("INOUT NESTED PROP: PASS");
      $finish;
   end
endmodule
