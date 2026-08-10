// Statement-form methods on a parameterized class static container must use
// the selected specialization's storage, not the unspecialized class signal.
package param_static_container_pkg;
  class bucket #(int TAG = 0);
    static int values[$];
  endclass
endpackage

module sv_param_class_static_container_method;
  import param_static_container_pkg::*;

  initial begin
    bucket#(1)::values.delete();
    bucket#(2)::values.delete();

    bucket#(1)::values.push_back(11);
    bucket#(1)::values.push_back(12);
    bucket#(2)::values.push_back(21);

    if (bucket#(1)::values.size() !== 2
        || bucket#(1)::values[0] !== 11
        || bucket#(1)::values[1] !== 12
        || bucket#(2)::values.size() !== 1
        || bucket#(2)::values[0] !== 21)
      $fatal(1, "specialized static container storage was not isolated");
    $display("PASSED");
  end
endmodule
