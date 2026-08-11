class fixed_index_mode_item;
  rand bit [3:0] descending[5:3];
  rand bit [3:0] ascending[3:5];
  rand bit [3:0] matrix[2:1][4:3];
endclass

module test;
  initial begin
    fixed_index_mode_item item;
    int descending_index;
    int ascending_index;
    int bad_index;
    bit [3:0] frozen_descending;
    bit [3:0] frozen_ascending;
    bit [3:0] frozen_matrix[4:3];

    item = new;
    item.srandom(32'h789a_bcde);
    descending_index = 5;
    ascending_index = 3;
    bad_index = 99;

    item.descending[descending_index].rand_mode(0);
    item.ascending[ascending_index].rand_mode(0);
    item.matrix[2].rand_mode(0);

    if (item.descending[5].rand_mode() !== 0
        || item.descending[4].rand_mode() !== 1
        || item.descending[3].rand_mode() !== 1)
      $fatal(1, "descending fixed-array index mapped to the wrong leaf");
    if (item.ascending[3].rand_mode() !== 0
        || item.ascending[4].rand_mode() !== 1
        || item.ascending[5].rand_mode() !== 1)
      $fatal(1, "ascending fixed-array index mapped to the wrong leaf");
    if (item.matrix[2].rand_mode() !== 0
        || item.matrix[2][4].rand_mode() !== 0
        || item.matrix[2][3].rand_mode() !== 0
        || item.matrix[1].rand_mode() !== 1)
      $fatal(1, "multidimensional subarray mode mapped to the wrong leaves");

    // A runtime out-of-range word select is a no-op for the setter and
    // reads disabled for the query; it must not corrupt any valid leaf.
    item.descending[bad_index].rand_mode(0);
    if (item.descending[bad_index].rand_mode() !== 0
        || item.descending[4].rand_mode() !== 1)
      $fatal(1, "out-of-range rand_mode access corrupted valid state");

    frozen_descending = item.descending[5];
    frozen_ascending = item.ascending[3];
    frozen_matrix[4] = item.matrix[2][4];
    frozen_matrix[3] = item.matrix[2][3];
    repeat (8) begin
      if (item.randomize() !== 1)
        $fatal(1, "fixed-index randomize failed");
      if (item.descending[5] !== frozen_descending
          || item.ascending[3] !== frozen_ascending
          || item.matrix[2][4] !== frozen_matrix[4]
          || item.matrix[2][3] !== frozen_matrix[3])
        $fatal(1, "disabled fixed-array leaf or subarray changed");
    end

    item.descending.rand_mode(1);
    item.ascending.rand_mode(1);
    item.matrix.rand_mode(1);
    if (item.descending.rand_mode() !== 1
        || item.ascending.rand_mode() !== 1
        || item.matrix.rand_mode() !== 1)
      $fatal(1, "whole-array setter did not restore every fixed leaf");

    $display("PASSED");
  end
endmodule
