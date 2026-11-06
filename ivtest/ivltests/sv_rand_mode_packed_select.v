class packed_mode_item;
  rand bit [7:0] value;
endclass

module test;
  initial begin
    packed_mode_item item;
    item = new;
    item.value[0].rand_mode(0);
    $display("packed part-select query=%0d", item.value[7:4].rand_mode());
  end
endmodule
