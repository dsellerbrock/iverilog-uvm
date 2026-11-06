class fixed_array_query_item;
  rand bit [3:0] matrix[3][2];
  rand bit [3:0] values[4];
endclass

module test;
  initial begin
    fixed_array_query_item item;
    int mode;
    item = new;
    mode = item.matrix[2].rand_mode();
    mode = item.values.rand_mode();
  end
endmodule
