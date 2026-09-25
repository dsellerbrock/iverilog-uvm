package otp_range_pkg;
  typedef struct packed {
    int unsigned offset;
    int unsigned size;
  } part_info_t;
  localparam part_info_t PartInfo [2] =
      '{'{offset:4, size:16}, '{offset:40, size:16}};
  localparam int DigestSize = 2;
  localparam int FirstIdx = 0, SecondIdx = 1;
  localparam int FirstLo = PartInfo[FirstIdx].offset;
  localparam int FirstHi = PartInfo[FirstIdx].offset + PartInfo[FirstIdx].size
                         - DigestSize - 1;
  localparam int SecondLo = PartInfo[SecondIdx].offset;
  localparam int SecondHi = PartInfo[SecondIdx].offset + PartInfo[SecondIdx].size
                          - DigestSize - 1;
endpackage

import otp_range_pkg::*;

class member_range_item;
  rand bit part_idx;
  rand bit [31:0] dai_addr;
  constraint addr_c {
    if (part_idx == FirstIdx)
      dai_addr inside {[PartInfo[FirstIdx].offset :
                        (PartInfo[FirstIdx].offset + PartInfo[FirstIdx].size
                         - DigestSize - 1)]};
    if (part_idx == SecondIdx)
      dai_addr inside {[PartInfo[SecondIdx].offset :
                        (PartInfo[SecondIdx].offset + PartInfo[SecondIdx].size
                         - DigestSize - 1)]};
    solve part_idx before dai_addr;
  }
endclass

class alias_range_item;
  rand bit part_idx;
  rand bit [31:0] dai_addr;
  constraint addr_c {
    if (part_idx == FirstIdx) dai_addr inside {[FirstLo:FirstHi]};
    if (part_idx == SecondIdx) dai_addr inside {[SecondLo:SecondHi]};
  }
endclass

class mutable_range_item;
  bit [31:0] lo;
  rand bit [31:0] dai_addr;
  constraint addr_c { dai_addr inside {[lo:lo+1]}; }
endclass

class shadow_range_item;
  bit [31:0] offset;
  rand bit [31:0] dai_addr;
  constraint addr_c {
    dai_addr == PartInfo[FirstIdx].offset;
    dai_addr != offset;
  }
endclass

class qualified_range_item;
  rand bit [31:0] dai_addr;
  constraint addr_c {
    dai_addr == otp_range_pkg::PartInfo[FirstIdx].offset;
  }
endclass

module test;
  member_range_item member_item;
  alias_range_item alias_item;
  mutable_range_item mutable_item;
  shadow_range_item shadow_item;
  qualified_range_item qualified_item;
  initial begin
    member_item = new;
    alias_item = new;
    mutable_item = new;
    shadow_item = new;
    qualified_item = new;

    // The scalar aliases prove the conditional inside solver path is live.
    if (!alias_item.randomize() with {part_idx == 0; dai_addr == 4;}
        || alias_item.dai_addr != 4) $fatal(1, "alias lower boundary");
    alias_item.part_idx = 1;
    alias_item.dai_addr = 44;
    if (alias_item.randomize() with {part_idx == 0; dai_addr == 18;})
      $fatal(1, "alias adjacent address accepted");
    if (alias_item.part_idx != 1 || alias_item.dai_addr != 44)
      $fatal(1, "alias failed solve changed state");

    if (!member_item.randomize() with {part_idx == 0; dai_addr == 4;}
        || member_item.part_idx != 0 || member_item.dai_addr != 4)
      $fatal(1, "first lower boundary");
    if (!member_item.randomize() with {part_idx == 0; dai_addr == 17;}
        || member_item.part_idx != 0 || member_item.dai_addr != 17)
      $fatal(1, "first upper boundary");
    if (!member_item.randomize() with {part_idx == 1; dai_addr == 40;}
        || member_item.part_idx != 1 || member_item.dai_addr != 40)
      $fatal(1, "second lower boundary");
    if (!member_item.randomize() with {part_idx == 1; dai_addr == 53;}
        || member_item.part_idx != 1 || member_item.dai_addr != 53)
      $fatal(1, "second upper boundary");

    member_item.part_idx = 1;
    member_item.dai_addr = 44;
    if (member_item.randomize() with {part_idx == 0; dai_addr == 3;})
      $fatal(1, "first below range accepted");
    if (member_item.randomize() with {part_idx == 0; dai_addr == 18;})
      $fatal(1, "first above range accepted");
    if (member_item.randomize() with {part_idx == 1; dai_addr == 39;})
      $fatal(1, "second below range accepted");
    if (member_item.randomize() with {part_idx == 1; dai_addr == 54;})
      $fatal(1, "second above range accepted");
    if (member_item.part_idx != 1 || member_item.dai_addr != 44)
      $fatal(1, "failed solve changed state");

    // A mutable class property must be read at each randomize call.
    mutable_item.lo = 90;
    if (!mutable_item.randomize() with {dai_addr == 90;})
      $fatal(1, "mutable initial range");
    mutable_item.lo = 100;
    if (mutable_item.randomize() with {dai_addr == 90;})
      $fatal(1, "mutable state was frozen");
    if (mutable_item.dai_addr != 90)
      $fatal(1, "mutable failed solve changed state");
    if (!mutable_item.randomize() with {dai_addr == 100;})
      $fatal(1, "mutable updated range");

    shadow_item.offset = 100;
    if (!shadow_item.randomize() || shadow_item.dai_addr != 4)
      $fatal(1, "selected member bound to shadow property");
    shadow_item.offset = 4;
    if (shadow_item.randomize() || shadow_item.dai_addr != 4)
      $fatal(1, "shadow property update was ignored or changed state");

    if (!qualified_item.randomize() || qualified_item.dai_addr != 4)
      $fatal(1, "package-qualified selected member");
    if (qualified_item.randomize() with {dai_addr == 5;})
      $fatal(1, "package-qualified selected member lost constraint");
    if (qualified_item.dai_addr != 4)
      $fatal(1, "package-qualified failed solve changed state");

    $display("PASSED");
  end
endmodule
