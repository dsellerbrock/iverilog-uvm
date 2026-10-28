class sv_static_method_instance_access;
  int value;
  function int instance_method();
    return value;
  endfunction
  static function int via_this();
    return this.value;
  endfunction
  static function int via_implicit_member();
    return value;
  endfunction
  static function int via_instance_method();
    return instance_method();
  endfunction
  static function int via_this_handle();
    return this == null;
  endfunction
endclass

module sv_static_method_instance_access_fail;
  int unused;
  initial unused = sv_static_method_instance_access::via_this_handle();
endmodule
