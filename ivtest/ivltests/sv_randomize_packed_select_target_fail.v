class packed_target_item;
  rand bit [7:0] data;
endclass

module test;
  packed_target_item item;
  initial begin
    item = new;
    // 18.11's argument list names properties; a select is an expression.
    void'(item.randomize(data[3:0]));
  end
endmodule
