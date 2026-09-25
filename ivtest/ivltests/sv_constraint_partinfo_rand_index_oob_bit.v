// IEEE 1800-2017 7.4.6 Table 7-1; 2023 7.4.5 Table 7-1.
package otp_rand_partinfo_bit_pkg;
  typedef struct packed { bit secret; } part_info_t;
  localparam part_info_t PartInfo [2] =
      '{'{secret:1'b0}, '{secret:1'b1}};
endpackage

import otp_rand_partinfo_bit_pkg::*;

class otp_rand_bit_item;
  rand bit [1:0] part_idx;
  rand bit [4:0] dai_addr;
  constraint blank_c {
    dai_addr % 4 == 0;
    if (PartInfo[part_idx].secret) dai_addr % 8 == 0;
  }
endclass

module test;
  otp_rand_bit_item item;
  initial begin
    item = new;
    if (!item.randomize() with {part_idx == 1; dai_addr == 8;})
      $fatal(1, "in-range secret partition rejected");
    item.part_idx = 0;
    item.dai_addr = 4;
    if (item.randomize() with {part_idx == 1; dai_addr == 4;})
      $fatal(1, "in-range secret guard was dropped");
    if (!item.randomize() with {part_idx == 2; dai_addr == 4;}
        || item.part_idx != 2 || item.dai_addr != 4)
      $fatal(1, "two-state out-of-range read was not zero");
    $display("PASSED");
  end
endmodule
