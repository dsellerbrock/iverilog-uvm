module sv_nettype_class_scope_scan;
  nettype logic logic_net;
  logic_net data;

  class base_c;
    int value;

    function new(int initial_value = 3);
      value = initial_value;
    endfunction

    function int increment();
      value += 1;
      return value;
    endfunction
  endclass

  class derived_c extends base_c;
    function new(int initial_value = 7);
      super.new(initial_value);
    endfunction
  endclass

  derived_c object;

  initial begin
    object = new(37);
    if ($bits(data) != 1 || object.increment() != 38 || object.value != 38)
      $fatal(1, "nettype finish scan corrupted an unrelated class scope");
    $display("PASSED");
  end
endmodule
