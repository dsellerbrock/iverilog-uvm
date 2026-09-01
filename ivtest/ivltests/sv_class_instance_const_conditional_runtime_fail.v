// IEEE 1800-2017/2023 8.19: the second site is legal when TAKE_FIRST is
// false and fails dynamically only when both assignments execute.
module top;
  class conditional_c;
    const bit [7:0] value;
    extern function new(bit take_first, bit enter_body);
  endclass

  function conditional_c::new(bit take_first, bit enter_body);
    if (take_first)
      for (value = 8'h91; enter_body; )
        $fatal(1, "zero-trip conditional for-loop entered its body");
    this.value = 8'h92;
  endfunction

  conditional_c legal_object, failing_object;
  initial begin
    legal_object = new(0, 0);
    if (legal_object.value !== 8'h92)
      $fatal(1, "legal path did not initialize the object");
    failing_object = new(1, 0);
    $display("FAILED");
  end
endmodule
