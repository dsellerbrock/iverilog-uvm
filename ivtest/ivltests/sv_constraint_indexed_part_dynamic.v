// Variable-base indexed part-selects in class constraints (IEEE 1800 11.5.1).
class packed_part_item;
  rand bit [7:0] down;
  rand bit [0:7] up;
  rand bit [-3:4] signed_range;
  rand bit [1:0][7:0] multi;
  rand logic [7:0] four_state;
  rand int index;
endclass

module test;
  packed_part_item item;
  initial begin
    item = new;
    if (!item.randomize() with {
      item.index == 5;
      item.down[item.index +: 3] == 3'b101;
    }) $fatal(1, "descending upper-bound indexed select failed");
    if (item.down[7:5] !== 3'b101)
      $fatal(1, "descending selected bits have wrong order");

    if (!item.randomize() with {
      item.index == 2;
      item.down[item.index -: 3] == 3'b110;
    }) $fatal(1, "descending minus indexed select failed");
    if (item.down[2:0] !== 3'b110)
      $fatal(1, "descending minus selected bits have wrong order");

    if (!item.randomize() with {
      item.index == 0;
      item.up[item.index +: 3] == 3'b011;
    }) $fatal(1, "ascending lower-bound indexed select failed");
    if (item.up[0:2] !== 3'b011)
      $fatal(1, "ascending selected bits have wrong order");

    if (!item.randomize() with {
      item.index == 5;
      item.four_state[item.index +: 3] == 3'b110;
    }) $fatal(1, "four-state indexed select failed");
    if (item.four_state[7:5] !== 3'b110)
      $fatal(1, "four-state selected bits have wrong order");

    if (!item.randomize() with {
      item.index == 2;
      item.signed_range[item.index +: 3] == 3'b101;
    }) $fatal(1, "negative declared-index boundary failed");
    if (item.signed_range[item.index +: 3] !== 3'b101)
      $fatal(1, "negative declared-index selection has wrong order");

    if (!item.randomize() with {
      item.index == 1;
      item.multi[item.index +: 1] == 8'hA5;
    }) $fatal(1, "multidimensional packed select failed");
    if (item.multi[1] !== 8'hA5)
      $fatal(1, "multidimensional selected element is wrong");

    if (item.randomize() with {
      item.index == 6;
      item.down[item.index +: 3] == 3'b001;
    }) $fatal(1, "partly out-of-range indexed select was accepted");
    $display("PASSED");
  end
endmodule
