package class_static_get_bad_receiver_pkg;
  class has_value;
    function int value();
      return 7;
    endfunction
  endclass

  class no_value;
  endclass

  class reader #(type ITEM = has_value);
    static ITEM item;

    static function int read();
      // The concrete no_value specialization must not fall back to the
      // default has_value receiver when this member is resolved.
      return item.value();
    endfunction
  endclass
endpackage

module sv_class_static_get_bad_receiver_fail;
  import class_static_get_bad_receiver_pkg::*;
  int sink;

  initial sink = reader#(no_value)::read();
endmodule
