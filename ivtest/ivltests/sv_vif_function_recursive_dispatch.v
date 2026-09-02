// IEEE 1800-2017/2023 13.4.1 and 25.9: an automatic interface function may
// recursively call the same function through another virtual handle. Its
// body must remain available while the outer candidate is still elaborating,
// and each invocation must receive an independent automatic frame.
interface vif_function_recursive_if;
  int calls = 0;

  function automatic int factorial(
      input int value, input virtual vif_function_recursive_if next);
    calls += 1;
    if (value <= 1)
      return 1;
    return value * next.factorial(value - 1, next);
  endfunction
endinterface

module sv_vif_function_recursive_dispatch;
  vif_function_recursive_if dut_if();
  virtual vif_function_recursive_if vif;
  int result;

  initial begin
    vif = dut_if;
    result = vif.factorial(5, vif);
    if (result != 120 || dut_if.calls != 5)
      $fatal(1, "recursive virtual-interface function dispatch failed");
    $display("PASSED");
  end
endmodule
