class static_method_instance_access;
  int value = 7;

  static function int get_value();
    return value;
  endfunction

  static function static_method_instance_access get_self();
    return this;
  endfunction
endclass

module test;
  initial begin
    static_method_instance_access::get_value();
    static_method_instance_access::get_self();
  end
endmodule
