// IEEE 1800-2017/2023 7.4.5, 18.3, and 18.5: packed element
// selections with random indices remain integral constraint expressions.
class logic_bit_select;
  rand logic [3:0][1:0] m;
  rand bit [1:0] i;
  constraint selected_bit { m[i][1] == 1'b1; }
endclass
class logic_element_select;
  rand logic [3:0][1:0] m;
  rand bit [1:0] i;
  constraint selected_element { m[i] == 2'b10; }
endclass
class bit_bit_select;
  rand bit [3:0][1:0] m;
  rand bit [1:0] i;
  constraint selected_bit { m[i][1] == 1'b1; }
endclass
class bit_element_select;
  rand bit [3:0][1:0] m;
  rand bit [1:0] i;
  constraint selected_element { m[i] == 2'b10; }
endclass
module tb;
  logic_bit_select lb;
  logic_element_select le;
  bit_bit_select bb;
  bit_element_select be;
  initial begin
    lb = new; le = new; bb = new; be = new;
    if (!lb.randomize() || lb.m[lb.i][1] !== 1'b1) $fatal(1, "logic bit");
    if (!le.randomize() || le.m[le.i] !== 2'b10) $fatal(1, "logic element");
    if (!bb.randomize() || bb.m[bb.i][1] !== 1'b1) $fatal(1, "bit bit");
    if (!be.randomize() || be.m[be.i] !== 2'b10) $fatal(1, "bit element");
    $display("PASSED");
  end
endmodule
