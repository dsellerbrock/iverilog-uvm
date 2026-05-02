// Test super.X() through paramclass-with-paramclass-parent inheritance.
// This is the OpenTitan cip_base_env_cfg #(RAL_T) extends dv_base_env_cfg #(RAL_T)
// pattern where both parameterizations carry the same type parameter.
class base;
   int counter;
   virtual function void mark();
      counter++;
   endfunction
endclass

class mid_param #(type T = int) extends base;
   virtual function void mark();
      super.mark();   // base::mark
      counter += 10;
   endfunction
endclass

class top_param #(type T = int) extends mid_param #(T);
   virtual function void mark();
      super.mark();  // → mid_param #(T)::mark — must NOT recurse
      counter += 100;
   endfunction
endclass

module top;
   top_param #(int) m;
   initial begin
      m = new();
      m.mark();
      if (m.counter != 111) $display("FAIL: counter=%0d (expected 111)", m.counter);
      else $display("SUPER PARAMCLASS PARENT-PARAM: PASS");
      $finish;
   end
endmodule
