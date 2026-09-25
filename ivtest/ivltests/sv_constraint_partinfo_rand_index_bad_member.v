package otp_rand_partinfo_bad_pkg;
  typedef struct packed { logic secret; } part_info_t;
  localparam part_info_t PartInfo [2] =
      '{'{secret:1'b0}, '{secret:1'b1}};
endpackage

import otp_rand_partinfo_bad_pkg::*;

class otp_rand_bad_member_item;
  rand bit part_idx;
  rand bit [4:0] dai_addr;
  constraint bad_c {
    if (PartInfo[part_idx].missing) dai_addr % 8 == 0;
  }
endclass

module test;
  otp_rand_bad_member_item item;
  initial item = new;
endmodule
