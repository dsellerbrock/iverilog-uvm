// IEEE 1800-2017/2023 18.3: only a selected X/Z leaf is erroneous.
package otp_rand_x_leaf_pkg;
  typedef struct packed { logic secret; } part_info_t;
  localparam part_info_t PartInfo [3] =
      '{'{secret:1'bx}, '{secret:1'b0}, '{secret:1'b1}};
endpackage

import otp_rand_x_leaf_pkg::*;

class x_leaf_item;
  rand bit [1:0] part_idx;
  rand bit [4:0] dai_addr;
  constraint blank_c {
    if (PartInfo[part_idx].secret) dai_addr % 8 == 0;
  }
endclass

module test;
  x_leaf_item item;
  initial begin
    item = new;
    if (!item.randomize() with {part_idx == 1; dai_addr == 4;})
      $fatal(1, "unselected X leaf poisoned valid solve");
    if (!item.randomize() with {part_idx == 2; dai_addr == 8;})
      $fatal(1, "defined secret leaf rejected");
    if (item.randomize() with {part_idx == 2; dai_addr == 4;})
      $fatal(1, "defined secret leaf lost guard");
    item.part_idx = 1;
    item.dai_addr = 4;
    if (item.randomize() with {part_idx == 0; dai_addr == 4;})
      $fatal(1, "selected X leaf did not fail");
    if (item.part_idx != 1 || item.dai_addr != 4)
      $fatal(1, "failed X solve changed object state");
    $display("PASSED");
  end
endmodule
