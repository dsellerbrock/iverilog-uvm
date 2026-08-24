// Package-qualified calls through a class's nested typedef must retain the
// package, class specialization, typedef, and final static-method scope.
package cip_base_pkg;
  class registry #(int TAG = 0);
    static int selected = -1;

    static function void set_type_override(int wrapper);
      selected = wrapper + TAG;
    endfunction

    static function int get_selected();
      return selected;
    endfunction
  endclass

  class cip_tl_seq_item;
    typedef registry#(0) type_id;
  endclass

  class tagged_item #(int TAG = 0);
    typedef registry#(TAG) type_id;
  endclass

  class xbar_seq_err_item;
    static function int get_type();
      return 41;
    endfunction
  endclass
endpackage

module sv_package_nested_static_call;
  import cip_base_pkg::*;
  int default_value;
  int first_value;
  int second_value;

  initial begin
    // This is the package/class/nested-registry spelling used by OpenTitan.
    cip_base_pkg::cip_tl_seq_item::type_id::set_type_override(
        xbar_seq_err_item::get_type());
    cip_base_pkg::tagged_item#(1)::type_id::set_type_override(
        xbar_seq_err_item::get_type());
    cip_base_pkg::tagged_item#(2)::type_id::set_type_override(50);

    default_value =
        cip_base_pkg::cip_tl_seq_item::type_id::get_selected();
    first_value =
        cip_base_pkg::tagged_item#(1)::type_id::get_selected();
    second_value =
        cip_base_pkg::tagged_item#(2)::type_id::get_selected();

    if (default_value != 41 || first_value != 42 || second_value != 52)
      $fatal(1, "wrong registry values: default=%0d first=%0d second=%0d",
             default_value, first_value, second_value);
    $display("PASSED");
  end
endmodule
