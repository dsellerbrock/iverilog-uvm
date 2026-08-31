// IEEE 1800-2017/2023 8.19: the second site is legal when TAKE_FIRST is
// false and fails dynamically only when both assignments execute.
module top;
  class conditional_c;
    const bit [7:0] value;
    function new(bit take_first);
      if (take_first)
        value = 8'h91;
      this.value = 8'h92;
    endfunction
  endclass

  conditional_c legal_object, failing_object;
  initial begin
    legal_object = new(0);
    if (legal_object.value !== 8'h92)
      $fatal(1, "legal path did not initialize the object");
    failing_object = new(1);
    $display("FAILED");
  end
endmodule
