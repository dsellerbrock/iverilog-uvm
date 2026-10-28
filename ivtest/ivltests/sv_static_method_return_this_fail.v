class sv_static_method_return_this;
  static function sv_static_method_return_this get_self();
    return this;
  endfunction
endclass

module sv_static_method_return_this_fail;
  sv_static_method_return_this handle;
  initial handle = sv_static_method_return_this::get_self();
endmodule
