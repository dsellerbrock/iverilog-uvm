// An out-of-range four-state packed bit read cannot satisfy a constraint
// even when its two-state placeholder would be zero (2017 7.4.6;
// 2023 7.4.5; both 18.3).
typedef enum logic [1:0] { E0 = 0, E1 = 1 } enum_logic_t;
class logic_constant_oob;
  rand logic [1:0] v;
  constraint k { v[64'hffffffffffffffff] == 1'b0; }
endclass
class logic_symbolic_oob;
  rand logic [1:0] v;
  rand bit [1:0] idx;
  constraint k { idx == 2; v[idx] == 1'b0; }
endclass
class enum_symbolic_oob;
  rand enum_logic_t v;
  rand bit [1:0] idx;
  constraint k { idx == 2; v[idx] == 1'b0; }
endclass
class bit_constant_oob;
  rand bit [1:0] v;
  constraint k { v[64'hffffffffffffffff] == 1'b0; }
endclass
class bit_constant_nonzero;
  rand bit [1:0] v;
  constraint k { v[64'hffffffffffffffff] == 1'b1; }
endclass
class bit_symbolic_nonzero;
  rand bit [1:0] v;
  rand bit [1:0] idx;
  constraint k { idx == 2; v[idx] == 1'b1; }
endclass
class logic_signed_negative;
  rand logic [1:0] v;
  rand bit signed [1:0] idx;
  constraint k { idx == -1; v[idx] == 1'b0; }
endclass
class bit_signed_negative;
  rand bit [1:0] v;
  rand bit signed [1:0] idx;
  constraint k { idx == -1; v[idx] == 1'b0; }
endclass
module test;
  initial begin
    logic_constant_oob c;
    logic_symbolic_oob s;
    enum_symbolic_oob e;
    bit_constant_oob b;
    bit_constant_nonzero bc;
    bit_symbolic_nonzero bs;
    logic_signed_negative sn;
    bit_signed_negative bn;
    c = new; s = new; e = new; b = new; bc = new; bs = new;
    sn = new; bn = new;
    s.v = 2'b10; s.idx = 0;
    if (c.randomize() || s.randomize() || e.randomize())
      $fatal(1, "out-of-range four-state bit read succeeded");
    if (s.v != 2'b10 || s.idx != 0)
      $fatal(1, "failed four-state solve changed object state");
    if (!b.randomize())
      $fatal(1, "out-of-range two-state constant read was not zero");
    if (bc.randomize() || bs.randomize())
      $fatal(1, "out-of-range two-state read matched one");
    if (sn.randomize() || !bn.randomize() || bn.idx != -1)
      $fatal(1, "signed negative packed index semantics failed");
    $display("PASSED");
  end
endmodule
