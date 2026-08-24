// Parsing a package/class/nested static call must not weaken ordinary method
// arity checks in either statement or expression position.
package package_nested_static_fail_pkg;
  class registry;
    static function void set(int value);
    endfunction

    static function int get();
      return 1;
    endfunction
  endclass

  class item;
    typedef registry type_id;
  endclass
endpackage

module sv_package_nested_static_call_fail;
  int value;

  initial begin
    package_nested_static_fail_pkg::item::type_id::set();
    value = package_nested_static_fail_pkg::item::type_id::get(1);
  end
endmodule
