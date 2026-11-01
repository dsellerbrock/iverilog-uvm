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

module test;
  logic_bit_select lb;
  logic_element_select le;
  bit_bit_select bb;
  bit_element_select be;
  integer n;

  initial begin
    lb = new;
    le = new;
    bb = new;
    be = new;
    for (n = 0; n < 20; n = n + 1) begin
      if (!lb.randomize() || lb.m[lb.i][1] !== 1'b1) begin
        $display("FAIL logic bit select");
        $finish;
      end
      if (!le.randomize() || le.m[le.i] !== 2'b10) begin
        $display("FAIL logic element select");
        $finish;
      end
      if (!bb.randomize() || bb.m[bb.i][1] !== 1'b1) begin
        $display("FAIL bit bit select");
        $finish;
      end
      if (!be.randomize() || be.m[be.i] !== 2'b10) begin
        $display("FAIL bit element select");
        $finish;
      end
    end
    $display("PASS");
  end
endmodule
