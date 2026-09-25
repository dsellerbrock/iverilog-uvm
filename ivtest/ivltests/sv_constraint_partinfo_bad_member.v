package otp_bad_member_pkg;
  typedef struct packed {
    int unsigned offset;
    int unsigned size;
  } part_info_t;
  localparam part_info_t PartInfo [1] = '{'{offset:4, size:16}};
endpackage

import otp_bad_member_pkg::*;

class bad_member_item;
  rand bit [31:0] dai_addr;
  constraint addr_c {
    dai_addr inside {[PartInfo[0].missing : PartInfo[0].size]};
  }
endclass

module test;
  bad_member_item item;
  initial item = new;
endmodule
