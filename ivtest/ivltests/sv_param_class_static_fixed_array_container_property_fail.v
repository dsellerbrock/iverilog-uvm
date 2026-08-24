// A concrete parameterized-class specialization must retain the same
// signal-backed storage guard. The scan repeats after lazy specialization
// finalization; this reducer pins the shape, not its exact visibility phase.
package param_static_fixed_array_container_pkg;
  class holder #(int TAG = 0);
    static int values[2][$];

    static function int get_tag();
      return TAG;
    endfunction
  endclass
endpackage

module sv_param_class_static_fixed_array_container_property_fail;
  import param_static_fixed_array_container_pkg::*;

  initial begin
    if (holder#(17)::get_tag() != 17)
      $fatal(1, "wrong specialization");
  end
endmodule
