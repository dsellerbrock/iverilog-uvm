module issue2335_nonleaf_indexed_part_select;
  logic [1:0][2:0][7:0] value;
  integer outer_index;
  integer inner_index;

  initial begin
    value = 48'h0123456789ab;
    outer_index = 0;
    inner_index = 2;
    if (value[outer_index][inner_index +: 2] !== 16'hxx67)
      $fatal(1, "partial out-of-range non-leaf part-select did not return xx67");

    inner_index = 3;
    if (value[outer_index][inner_index] !== 8'hxx)
      $fatal(1, "out-of-range non-leaf element did not return xx");

    $display("PASSED");
  end
endmodule
