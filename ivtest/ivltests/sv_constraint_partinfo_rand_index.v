// IEEE 1800-2017 7.4.6, 18.3, 18.5.7; 2023 7.4.5, 18.3, 18.5.6.
package otp_rand_partinfo_pkg;
  typedef struct packed {
    logic [7:0] offset;
    logic secret;
    logic [7:0] size;
  } part_info_t;
  localparam part_info_t PartInfo [2] =
      '{'{offset:8, secret:1'b0, size:16},
        '{offset:32, secret:1'b1, size:16}};
endpackage

import otp_rand_partinfo_pkg::*;

class otp_rand_addr_item;
  rand bit part_idx;
  rand bit [5:0] dai_addr;
  constraint blank_c {
    dai_addr % 4 == 0;
    if (PartInfo[part_idx].secret) dai_addr % 8 == 0;
    solve part_idx before dai_addr;
  }
endclass

module test;
  otp_rand_addr_item item;
  initial begin
    item = new;
    if (!item.randomize() with {part_idx == 0; dai_addr == 4;}
        || item.part_idx != 0 || item.dai_addr != 4)
      $fatal(1, "nonsecret partition lost four-byte alignment");
    if (!item.randomize() with {part_idx == 1; dai_addr == 8;}
        || item.part_idx != 1 || item.dai_addr != 8)
      $fatal(1, "secret partition rejected eight-byte alignment");
    if (!item.randomize() with {dai_addr == 4;}
        || item.part_idx != 0 || item.dai_addr != 4)
      $fatal(1, "address did not constrain random partition index");

    item.part_idx = 0;
    item.dai_addr = 4;
    if (item.randomize() with {part_idx == 0; dai_addr == 2;})
      $fatal(1, "nonsecret partition accepted unaligned address");
    if (item.randomize() with {part_idx == 1; dai_addr == 4;})
      $fatal(1, "secret partition accepted four-byte-only address");
    if (item.part_idx != 0 || item.dai_addr != 4)
      $fatal(1, "failed randomize changed object state");
    $display("PASSED");
  end
endmodule
