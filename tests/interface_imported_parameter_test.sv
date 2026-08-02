// IEEE 1800-2017 26.3/25: a named package import in an interface is
// visible while constructing both the instantiated and virtual-interface
// views of its members.
package interface_imported_parameter_pkg;
  parameter int Width = 13;
endpackage

interface interface_imported_parameter_if;
  import interface_imported_parameter_pkg::Width;
  logic [Width-1:0] data;
endinterface

package interface_imported_parameter_holder_pkg;
  class holder;
    virtual interface_imported_parameter_if vif;
  endclass
endpackage

module interface_imported_parameter_test;
  import interface_imported_parameter_holder_pkg::holder;
  interface_imported_parameter_if intf();
  holder obj;

  initial begin
    obj = new();
    obj.vif = intf;
    if ($bits(obj.vif.data) != 13) begin
      $display("INTERFACE IMPORTED PARAMETER TEST: FAIL bits=%0d",
               $bits(obj.vif.data));
      $finish(1);
    end
    $display("INTERFACE IMPORTED PARAMETER TEST: PASS");
    $finish(0);
  end
endmodule
