// A class member (or local) variable whose declared TYPE's name happens
// to coincide with an unrelated class's name elsewhere in the design must
// still dispatch as an ordinary object method call. Confirmed
// independently: slang (--std 1800-2017) accepts this, 0 errors.
//
// Real, unmodified OpenTitan DV source relies on exactly this shape
// (hw/dv/sv/dv_base_reg/dv_base_reg_field.sv's `mubi_cov` member, of type
// `dv_base_mubi_cov`, coincides with an unrelated parameterized
// `class mubi_cov #(...)` declared in the same file's sibling
// dv_base_mubi_cov.sv) -- widely used by many DV testbenches (tl_agent,
// every xbar_*_sim core across all three tops, and more).
//
// Before this fix, `receiver.method()` where `receiver` is a class member/
// local variable was misresolved as a bare reference to an unrelated
// class of the same name, rejected with "Parameterized class `name'
// requires an explicit #(...) specialization before ::." before ordinary
// method dispatch ever ran -- even though the actual code never uses `::`
// at all, only ordinary `.` member/method access. This is a real
// regression: confirmed clean at the L36-L40 baseline (commit 631bba6e8,
// PR #277), broken starting at the very next merge (PR #280, L43-L64).

// An unrelated parameterized class sharing its name with a plain member
// variable declared below -- the exact naming collision from the real
// OpenTitan file.
class mubi_cov #(parameter int Width = 4);
  static function int width(); return Width; endfunction
endclass

class dv_base_mubi_cov;
  int last_width;
  function void create_cov(int width);
    last_width = width;
  endfunction
endclass

class dv_base_reg_field;
  dv_base_mubi_cov mubi_cov;
  int last_width;
  function void create_mubi_cov(int width);
    mubi_cov = new();
    mubi_cov.create_cov(width);   // ordinary object method call, not `::`
    last_width = mubi_cov.last_width;
  endfunction
endclass

module main;
  int fails = 0;

  initial begin
    dv_base_reg_field f;
    f = new();
    f.create_mubi_cov(4);
    if (f.last_width != 4) begin
      $display("FAILED, last_width=%0d", f.last_width);
      fails++;
    end

    if (fails != 0) begin
      $display("FAILED, fails=%0d", fails);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
