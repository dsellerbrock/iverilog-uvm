class queue_holder;
  logic [7:0] data[$];
endclass

module test;
  queue_holder item;
  logic [7:0] value;

  initial begin
    item = new;
    value = item.data.pop_front(1);
  end
endmodule
