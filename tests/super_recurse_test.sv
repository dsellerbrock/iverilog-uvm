// Reproduce the OpenTitan cip_base_env_cfg / dv_base_env_cfg pattern
// where parameterized classes' super.X() resolution may recurse.
class uvm_object_x;
   string m_leaf_name;
   function new(string name = ""); m_leaf_name = name; endfunction
endclass

class dv_base_cfg_x #(type RAL_T = uvm_object_x) extends uvm_object_x;
   bit under_reset;

   function new(string name = "");
      super.new(name);
   endfunction

   virtual function void reset_asserted();
      this.under_reset = 1;
   endfunction
endclass

class cip_base_cfg_x #(type RAL_T = uvm_object_x) extends dv_base_cfg_x #(RAL_T);
   bit will_reset;
   function new(string name = "");
      super.new(name);
   endfunction

   virtual function void reset_asserted();
      super.reset_asserted();
      this.will_reset = 0;
   endfunction
endclass

class my_ral_block extends uvm_object_x; endclass

class my_env_cfg extends cip_base_cfg_x #(my_ral_block);
   function new(string name = ""); super.new(name); endfunction
endclass

module top;
   my_env_cfg c;
   initial begin
      c = new("cfg");
      c.reset_asserted();
      $display("under_reset=%0d will_reset=%0d", c.under_reset, c.will_reset);
      if (c.under_reset == 1 && c.will_reset == 0)
         $display("SUPER RECURSE TEST: PASS");
      else
         $display("SUPER RECURSE TEST: FAIL");
      $finish;
   end
endmodule
