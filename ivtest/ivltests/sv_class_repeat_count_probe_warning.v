// IEEE 1800-2017/2023 12.7.2: constructor-order analysis must observe a
// repeat count without elaborating it early. The ordinary expression pass
// owns the unresolved-name diagnostic, which shall appear exactly once.
module top;
  class missing_repeat_c;
    const int value;
    function new;
      repeat (missing_count)
        value = 1;
    endfunction
  endclass

  initial
    $display("PASSED");
endmodule
