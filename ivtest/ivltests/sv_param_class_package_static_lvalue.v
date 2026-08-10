package static_lvalue_pkg;
  class wrapper #(int VALUE = 11);
    static int value = VALUE;
  endclass
  typedef wrapper default_wrapper;
  typedef default_wrapper chained_wrapper;
endpackage

module sv_param_class_package_static_lvalue;
  initial begin
    static_lvalue_pkg::wrapper#()::value = 21;
    if (static_lvalue_pkg::default_wrapper::value !== 21
        || static_lvalue_pkg::chained_wrapper::value !== 21
        || static_lvalue_pkg::wrapper#(37)::value !== 37)
      $fatal(1, "package default storage mismatch");

    static_lvalue_pkg::wrapper#(37)::value = 41;
    static_lvalue_pkg::chained_wrapper::value = 23;
    if (static_lvalue_pkg::wrapper#()::value !== 23
        || static_lvalue_pkg::wrapper#(37)::value !== 41)
      $fatal(1, "package specialization storage split");
    $display("PASSED");
  end
endmodule
