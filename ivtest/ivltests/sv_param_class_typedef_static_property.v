// A class typedef selects the declared default specialization while an
// explicit #(...) selects its own static-property instance.
module sv_param_class_typedef_static_property;
  class wrapper #(int VALUE = 13);
    static int value = VALUE;
  endclass

  typedef wrapper default_wrapper;
  typedef default_wrapper chained_wrapper;
  initial begin
    default_wrapper alias_handle;
    chained_wrapper chained_handle;
    wrapper#() explicit_default_handle;

    default_wrapper::value = 23;
    if (type(alias_handle) != type(explicit_default_handle)
        || type(chained_handle) != type(explicit_default_handle)
        || wrapper#()::value !== 23
        || wrapper#(19)::value !== 19)
      $fatal(1, "static property specialization mismatch: %0d %0d",
             wrapper#()::value, wrapper#(19)::value);

    wrapper#()::value = 29;
    if (default_wrapper::value !== 29
        || chained_wrapper::value !== 29
        || wrapper#(19)::value !== 19)
      $fatal(1, "static property alias storage split: %0d %0d %0d",
             default_wrapper::value, chained_wrapper::value,
             wrapper#(19)::value);
    $display("PASSED");
  end
endmodule
