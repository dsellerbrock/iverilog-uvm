// IEEE 1800-2017/2023 8.19: one authorized source assignment can execute
// repeatedly, but the second execution on the same object is illegal.
module top;
  class loop_c;
    int mutable_prefix;
    const bit [7:0] untouched;
    const bit [7:0] value;
    function new(int count);
      mutable_prefix = count;
      repeat (count)
        value = 8'h81;
    endfunction
  endclass

  loop_c object;
  initial begin
    object = new(2);
    $display("FAILED");
  end
endmodule
