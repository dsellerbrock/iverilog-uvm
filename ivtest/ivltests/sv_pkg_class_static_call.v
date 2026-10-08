package pkg_class_static_call_pkg;
  class call_target;
    static int value;

    static function void set(int next_value);
      value = next_value;
    endfunction

    static task set_from_task(int next_value);
      value = next_value;
    endtask

    static function int get();
      return value;
    endfunction
  endclass

  class parameterized_target #(int WIDTH = 1);
    static int value;

    static function void set(int next_value);
      value = next_value + WIDTH;
    endfunction

    static function int get();
      return value;
    endfunction
  endclass
endpackage

module sv_pkg_class_static_call;
  initial begin
    pkg_class_static_call_pkg::call_target::set(5);
    if (pkg_class_static_call_pkg::call_target::value != 5)
      $fatal(1, "package class static task did not update its property");

    pkg_class_static_call_pkg::call_target::set_from_task(7);
    if (pkg_class_static_call_pkg::call_target::value != 7)
      $fatal(1, "package class static task call failed");

    void'(pkg_class_static_call_pkg::call_target::get());
    pkg_class_static_call_pkg::parameterized_target#(8)::set(1);
    if (pkg_class_static_call_pkg::parameterized_target#(8)::value != 9)
      $fatal(1, "parameterized package class static call failed");

    $display("PASSED");
  end
endmodule
