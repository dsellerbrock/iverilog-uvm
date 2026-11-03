// IEEE 1800-2017/2023 7.4.5 and 18.3/18.5: packed array element selects
// with rand indices are integral expressions that can appear in constraints.
class logic_bit_select;
  rand logic [3:0][1:0] m;
  rand bit [1:0] i;
  constraint c { m[i][1] == 1'b1; }
endclass

class logic_element_select;
  rand logic [3:0][1:0] m;
  rand bit [1:0] i;
  constraint c { m[i] == 2'b10; }
endclass

class bit_bit_select;
  rand bit [3:0][1:0] m;
  rand bit [1:0] i;
  constraint c { m[i][1] == 1'b1; }
endclass

class bit_element_select;
  rand bit [3:0][1:0] m;
  rand bit [1:0] i;
  constraint c { m[i] == 2'b10; }
endclass

module test;
  logic_bit_select logic_bit;
  logic_element_select logic_element;
  bit_bit_select bit_bit;
  bit_element_select bit_element;

  initial begin
    logic_bit = new;
    logic_element = new;
    bit_bit = new;
    bit_element = new;

    repeat (5) begin
      if (!logic_bit.randomize())
        $fatal(1, "logic packed bit-select randomization failed");
      if (logic_bit.m[logic_bit.i][1] !== 1'b1)
        $fatal(1, "logic packed bit-select constraint mismatch");

      if (!logic_element.randomize())
        $fatal(1, "logic packed element randomization failed");
      if (logic_element.m[logic_element.i] !== 2'b10)
        $fatal(1, "logic packed element constraint mismatch");

      if (!bit_bit.randomize())
        $fatal(1, "bit packed bit-select randomization failed");
      if (bit_bit.m[bit_bit.i][1] !== 1'b1)
        $fatal(1, "bit packed bit-select constraint mismatch");

      if (!bit_element.randomize())
        $fatal(1, "bit packed element randomization failed");
      if (bit_element.m[bit_element.i] !== 2'b10)
        $fatal(1, "bit packed element constraint mismatch");
    end

    $display("PASS: issue1847 packed rand indexing");
  end
endmodule
