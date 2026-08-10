// Inside a package, an exact lexical class/typedef with the package's own
// spelling must win for Class::property.method(). Do not normalize that call
// into a self-package variable reference.
package self_class_collision_pkg;
  int values[$];

  class self_class_collision_pkg;
    static int values[$];
  endclass

  function automatic void clear_class_values();
    self_class_collision_pkg::values.delete();
  endfunction

  function automatic void append_class_value(input int value);
    self_class_collision_pkg::values.push_back(value);
  endfunction

  function automatic int class_value_count();
    return self_class_collision_pkg::values.size();
  endfunction
endpackage

module sv_package_self_class_method_collision;
  initial begin
    self_class_collision_pkg::values.delete();
    self_class_collision_pkg::clear_class_values();
    self_class_collision_pkg::append_class_value(17);

    if (self_class_collision_pkg::class_value_count() !== 1
        || self_class_collision_pkg::values.size() !== 0)
      $fatal(1, "same-named class method receiver aliased package storage");
    $display("PASSED");
  end
endmodule
