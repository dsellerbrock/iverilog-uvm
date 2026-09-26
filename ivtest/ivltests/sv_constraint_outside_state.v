// A declared class constraint may read state outside the class (IEEE
// 1800-2017/2023 18.3): a package or compilation-unit variable is read when
// randomize() is called, and a const package array denotes its elements
// as an inside operand (11.4.13, 6.20.6). OpenTitan lc_ctrl_errors_vseq.sv:
// !(invalid_next_state inside {ValidDecodedStates}), a package
// const int ValidDecodedStates[].
package state_pkg;
  int limit = 5;
  const int CL [] = '{2, 4};
  const bit [7:0] FIX [3] = '{8'd10, 8'd20, 8'd30};
  typedef enum logic [319:0] {
    WA = {64'hDEAD_BEEF_0000_0001, 256'h1},
    WB = {64'hCAFE_F00D_0000_0002, 256'h2},
    WC = 320'h3
  } wide_e;
  const wide_e WIDE_OK [] = '{WA, WC};
endpackage
import state_pkg::*;

bit [3:0] unit_floor = 3;

class item;
  rand bit [3:0] a, b, c;
  rand bit [7:0] f;
  rand wide_e w;
  constraint c_scalar { a < limit; }
  constraint c_unit   { b >= unit_floor; b < 8; }
  constraint c_const  { !(c inside {CL}); c < 6; }
  constraint c_fixed  { f inside {FIX}; }
  constraint c_wide   { w inside {WIDE_OK}; }
endclass

module test;
  item it = new;
  bit failed = 0;
  int c0 = 0;

  task automatic check(string what, bit ok);
    if (!ok) begin
      $display("FAILED %s", what);
      failed = 1;
    end
  endtask

  initial begin
    repeat (40) begin
      check("randomize", it.randomize());
      check("package scalar", it.a < 5);
      check("unit scalar", it.b >= 3 && it.b < 8);
      check("const dynamic array", !(it.c inside {2, 4}) && it.c < 6);
      if (it.c == 0) c0++;
      check("const fixed array", it.f inside {10, 20, 30});
      check("wide const array", it.w inside {WA, WC});
    end
    check("const dynamic array spread", c0 > 0 && c0 < 40);
    limit = 2;
    unit_floor = 7;
    repeat (20) begin
      check("randomize after update", it.randomize());
      check("package scalar re-read", it.a < 2);
      check("unit scalar re-read", it.b == 7);
    end
    limit = 0;
    check("no value below zero", !it.randomize());
    if (!failed) $display("PASSED");
  end
endmodule
