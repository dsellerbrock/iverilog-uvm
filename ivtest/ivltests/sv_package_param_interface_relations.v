// Package-qualified parameterized interface-class relations use the same
// ownership path as an ordinary extends clause.  Preserve the arguments for
// both interface inheritance and class implementation.

package package_param_interface_base_pkg;
  interface class value_if #(type T = int);
    pure virtual function T value();
  endclass
endpackage

package package_param_interface_user_pkg;
  interface class byte_if extends
      package_param_interface_base_pkg::value_if #(byte);
  endclass

  class inherited_impl implements byte_if;
    virtual function byte value();
      return 8'h5a;
    endfunction
  endclass

  class direct_impl implements
      package_param_interface_base_pkg::value_if #(byte);
    virtual function byte value();
      return 8'ha5;
    endfunction
  endclass
endpackage

module sv_package_param_interface_relations;
  import package_param_interface_base_pkg::*;
  import package_param_interface_user_pkg::*;

  value_if#(byte) inherited_view;
  value_if#(byte) direct_view;
  inherited_impl inherited_object;
  direct_impl direct_object;

  initial begin
    inherited_object = new;
    direct_object = new;
    inherited_view = inherited_object;
    direct_view = direct_object;

    if (inherited_view.value() != 8'h5a
        || direct_view.value() != 8'ha5) begin
      $display("FAILED package-qualified interface relation arguments");
      $finish;
    end

    $display("PASSED");
  end
endmodule
