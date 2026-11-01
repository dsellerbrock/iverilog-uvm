class nested_packed_foreach;
  rand bit [1:0][3:0] two_level;
  rand bit [1:0][1:0][1:0] three_level;

  constraint packed_bits {
    foreach (two_level[i, j])
      two_level[i][j] == 1'((i + j) % 2);
    foreach (three_level[i, j, k])
      three_level[i][j][k] == 1'((i + j + k) % 2);
  }
endclass

module test;
  nested_packed_foreach item;

  initial begin
    item = new;
    if (!item.randomize()) $fatal(1, "nested packed foreach randomize failed");
    if (item.two_level !== 8'h5a)
      $fatal(1, "two packed dimensions: got %h expected 5a", item.two_level);
    if (item.three_level !== 8'h69)
      $fatal(1, "three packed dimensions: got %h expected 69", item.three_level);
    $display("%h %h", item.two_level, item.three_level);
  end
endmodule
