class packed_constraint_foreach;
  rand bit [1:0][1:0][1:0] value;

  constraint parity {
    foreach (value[i, j, k])
      value[i][j][k] == 1'((i + j + k) % 2);
  }
endclass

module test;
  bit [1:0][1:0][1:0] procedural_value;
  packed_constraint_foreach item;

  initial begin
    foreach (procedural_value[i, j, k])
      procedural_value[i][j][k] = 1'((i + j + k) % 2);

    item = new;
    if (!item.randomize()) $fatal(1, "packed constraint foreach randomize failed");
    if (item.value !== procedural_value)
      $fatal(1, "constraint foreach: got %h expected %h",
             item.value, procedural_value);
    if (item.value !== 8'h96)
      $fatal(1, "three packed dimensions: got %h expected 96", item.value);
    $display("%h", item.value);
  end
endmodule
