// IEEE 1800-2017/2023 8.19: a for-header initializer and a for-step
// assignment are distinct authorized source sites, but both may not execute
// for the same instance constant on one object.
module top;
  class for_step_c;
    int index;
    const bit [7:0] value;
    function new;
      // A continue reaches the for-step, so the second assignment executes.
      for (value = 8'ha1; index < 1; value = 8'ha2) begin
        index += 1;
        continue;
      end
    endfunction
  endclass

  for_step_c object;
  initial begin
    object = new;
    $display("FAILED");
  end
endmodule
