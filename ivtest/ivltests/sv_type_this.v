class registry #(type T = int);
  static function type(this) get();
    static type(this) cached;
    if (cached == null) cached = new;
    return cached;
  endfunction
endclass

class my_int_registry extends registry#(int);
  function type(this) other();
    return this;
  endfunction
endclass

module sv_type_this;
  initial begin
    registry#(byte) byte_instance;
    registry#(int) int_instance;
    my_int_registry derived_instance;

    byte_instance = registry#(byte)::get();
    int_instance = registry#(int)::get();
    derived_instance = new;
    if (byte_instance == null || int_instance == null ||
        derived_instance.other() != derived_instance)
      $fatal(1, "type(this) returned an incorrect class handle");

    $display("PASS sv_type_this");
  end
endmodule
