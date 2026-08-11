class packed_mode_item;
  rand bit [7:0] value;
endclass

module test;
  initial begin
    packed_mode_item item;
    bit [7:0] frozen;
    item = new;
    item.value = 8'ha5;
    frozen = item.value;

    item.value[0].rand_mode(0);
    if (item.value.rand_mode() !== 0
        || item.value[0].rand_mode() !== 0
        || item.value[7:4].rand_mode() !== 0)
      $fatal(1, "packed select did not control owning variable");
    if (item.randomize() !== 1 || item.value !== frozen)
      $fatal(1, "packed-select mode-off did not freeze owning variable");

    item.value[7:4].rand_mode(1);
    if (item.value.rand_mode() !== 1
        || item.value[0].rand_mode() !== 1
        || item.value[7:4].rand_mode() !== 1)
      $fatal(1, "packed part-select did not re-enable owning variable");

    $display("PASSED");
  end
endmodule
