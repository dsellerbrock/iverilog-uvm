// IEEE 1800-2017/2023 8.10.
class static_method_instance_access;
  int value = 7;
  static function int get_value();
    return value;
  endfunction
  function int get_instance_value();
    return 11;
  endfunction
  static function int call_instance_method();
    return get_instance_value();
  endfunction
  static function static_method_instance_access get_self();
    return this;
  endfunction
endclass

module sv_static_method_instance_access_fail;
  initial begin
    $display("%0d", static_method_instance_access::get_value());
    $display("%0d", static_method_instance_access::call_instance_method());
    $display("%p", static_method_instance_access::get_self());
  end
endmodule
