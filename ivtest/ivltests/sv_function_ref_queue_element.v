// IEEE 1800-2017/2023 13.5.2: a ref formal aliases the selected queue element.
module sv_function_ref_queue_element;
  int q[$];
  int result;
  int index;

  function automatic int increment(ref int value);
    value = value + 1;
    return value;
  endfunction

  initial begin
    q = '{1, 2};
    index = 1;
    result = increment(q[index]);
    if (result !== 3 || q[index] !== 3)
      $fatal(1, "ref queue element: result=%0d q[%0d]=%0d",
             result, index, q[index]);
    $display("PASSED");
  end
endmodule
