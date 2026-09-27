// num(), first() and last() of an enum variable are properties of its type
// (IEEE 1800-2017/2023 6.19.5), so a constraint may use them as constants
// (OpenTitan keymgr: `num_adv == state.num() + 1').
package kp;
  typedef enum logic [2:0] { StReset = 1, StInit = 2, StCreator = 4, StDisabled = 6 } state_e;
endpackage
class vseq;
  protected kp::state_e state;
  rand int unsigned num_adv;
  rand kp::state_e lo, hi;
  constraint num_adv_c { num_adv == state.num() + 1; }
  constraint bounds_c { lo == state.first(); hi == state.last(); }
endclass
module test;
  initial begin
    automatic vseq v = new;
    if (v.randomize() && v.num_adv == 5 && v.lo == kp::StReset && v.hi == kp::StDisabled)
      $display("PASSED");
    else
      $display("FAILED %0d %s %s", v.num_adv, v.lo.name, v.hi.name);
  end
endmodule
