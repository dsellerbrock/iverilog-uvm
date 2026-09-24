// Two nonoverlapping continuous drivers of one packed variable.
// Related to IEEE 1800-2017/2023 section 6.5 (variable drivers).
module packed_disjoint_continuous_min;
  logic [1:0][1:0] only_first;
  logic [1:0][1:0] disjoint;
  logic [1:0][1:0] dependent;
  assign only_first[0] = 2'b01;
  assign disjoint[0] = 2'b01;
  assign disjoint[1][0] = 1'b1;
  assign dependent[0] = 2'b01;
  assign dependent[1][0] = dependent[0][0];
  initial begin
    #1;
    $display("only_first=%b disjoint_low=%b disjoint_high_bit=%b dependent_low=%b dependent_high_bit=%b",
             only_first[0], disjoint[0], disjoint[1][0],
             dependent[0], dependent[1][0]);
    if (only_first[0] !== 2'b01) $fatal(1, "single driver failed");
    if (disjoint[0] !== 2'b01 || disjoint[1][0] !== 1'b1)
      $fatal(1, "disjoint continuous drivers lost");
    if (dependent[0] !== 2'b01 || dependent[1][0] !== 1'b1)
      $fatal(1, "disjoint dependent driver lost");
    $display("PASS disjoint drivers");
  end
endmodule
