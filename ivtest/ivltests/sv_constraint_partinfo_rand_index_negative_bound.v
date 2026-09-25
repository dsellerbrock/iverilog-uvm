// IEEE 1800-2017 7.4.6, 18.3; 2023 7.4.5, 18.3.
package otp_rand_negative_pkg;
  typedef struct packed { logic secret; } part_info_t;
  localparam part_info_t PartInfo [-1:0] =
      '{'{secret:1'b1}, '{secret:1'b0}};
endpackage

import otp_rand_negative_pkg::*;

class signed_index_item;
  rand logic signed [7:0] part_idx;
  rand bit [4:0] dai_addr;
  constraint blank_c {
    if (PartInfo[part_idx].secret) dai_addr % 8 == 0;
  }
endclass

class unsigned_index_item;
  rand bit [63:0] part_idx;
  rand bit [4:0] dai_addr;
  constraint blank_c {
    if (PartInfo[part_idx].secret) dai_addr % 8 == 0;
  }
endclass

module test;
  signed_index_item s;
  unsigned_index_item u;
  initial begin
    s = new;
    if (!s.randomize() with {part_idx == -1; dai_addr == 8;})
      $fatal(1, "signed negative bound rejected");
    if (s.randomize() with {part_idx == -1; dai_addr == 4;})
      $fatal(1, "signed negative bound lost secret guard");
    if (s.part_idx != -1 || s.dai_addr != 8)
      $fatal(1, "failed signed solve changed object state");
    u = new;
    u.part_idx = 0;
    u.dai_addr = 4;
    if (u.randomize() with {part_idx == 64'hffffffffffffffff;
                            dai_addr == 8;})
      $fatal(1, "unsigned max collided with signed negative bound");
    if (u.part_idx != 0 || u.dai_addr != 4)
      $fatal(1, "failed unsigned solve changed object state");
    $display("PASSED");
  end
endmodule
