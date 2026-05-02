// Test that a class registered via `uvm_object_utils has a non-empty type_name
// and can be created via factory.create_object_by_name(type_name).
module top;
   import uvm_pkg::*;
`include "uvm_macros.svh"

   class my_block extends uvm_object;
      `uvm_object_utils(my_block)
      function new(string name = "my_block"); super.new(name); endfunction
   endclass

   initial begin
      string tn;
      uvm_factory factory;
      uvm_object obj;
      tn = my_block::type_name;
      $display("type_name (no parens)='%s'", tn);
      if (tn == "") begin $display("FAIL: type_name no-parens form returned empty"); $finish; end
      tn = my_block::type_name();
      $display("type_name (parens)='%s'", tn);
      factory = uvm_factory::get();
      obj = factory.create_object_by_name(.requested_type_name(tn), .name("inst"));
      if (obj == null) begin
         $display("FAIL: factory.create_object_by_name(%s) returned null", tn);
         $finish;
      end
      $display("created: %s", obj.get_type_name());
      $display("FACTORY TYPENAME TEST: PASS");
      $finish;
   end
endmodule
