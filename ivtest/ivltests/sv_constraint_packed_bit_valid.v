// A symbolic packed bit index is valid in range for logic and reads zero
// out of range for bit (IEEE 1800-2017 7.4.6; 2023 7.4.5; both 18.3).
class logic_in_range;
  rand logic [1:0] v;
  rand bit [1:0] idx;
  constraint k { idx == 1; v[idx] == 1'b1; }
endclass
class bit_out_of_range;
  rand bit [1:0] v;
  rand bit [1:0] idx;
  constraint k { idx == 2; v[idx] == 1'b0; }
endclass
class logic_signed_in_range;
  rand logic [1:0] v;
  rand bit signed [1:0] idx;
  constraint k { idx == 1; v[idx] == 1'b1; }
endclass
class bit_signed_in_range;
  rand bit [1:0] v;
  rand bit signed [1:0] idx;
  constraint k { idx == 1; v[idx] == 1'b1; }
endclass
class guarded_logic_out_of_range;
  rand logic [1:0] v;
  rand bit [1:0] idx;
  constraint k { idx == 2; if (idx == 1) v[idx] == 1'b0; }
endclass
module test;
  initial begin
    logic_in_range l;
    bit_out_of_range b;
    logic_signed_in_range ls;
    bit_signed_in_range bs;
    guarded_logic_out_of_range g;
    l = new; b = new; ls = new; bs = new; g = new;
    if (!l.randomize() || l.idx != 1 || l.v[1] != 1'b1)
      $fatal(1, "in-range logic bit select failed");
    if (!b.randomize() || b.idx != 2)
      $fatal(1, "out-of-range two-state read was not zero");
    if (!ls.randomize() || ls.idx != 1 || ls.v[1] != 1'b1)
      $fatal(1, "valid narrow signed logic index failed");
    if (!bs.randomize() || bs.idx != 1 || bs.v[1] != 1'b1)
      $fatal(1, "valid narrow signed bit index failed");
    if (!g.randomize() || g.idx != 2)
      $fatal(1, "inactive four-state read affected solve");
    $display("PASSED");
  end
endmodule
