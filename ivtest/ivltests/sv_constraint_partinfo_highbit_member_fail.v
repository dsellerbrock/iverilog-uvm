package otp_highbit_member_pkg;
  typedef struct packed {
    bit [64:0] high;
  } part_info_t;
  localparam part_info_t PartInfo [1] =
      '{'{high:65'h1_0000_0000_0000_0000}};
endpackage

class highbit_member_item;
  rand bit value;
  constraint value_c {
    value == otp_highbit_member_pkg::PartInfo[0].high;
  }
endclass

module test;
  highbit_member_item item;
  initial item = new;
endmodule
