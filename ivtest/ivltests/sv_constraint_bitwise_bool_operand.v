// IEEE 1800-2017/2023 11.3 and 11.8: comparison results are one-bit
// integral operands when used by bitwise operators. Equality binds before &.
class reset_mask;
  rand bit [7:0] regwen;
  rand bit [7:0] ctrl_n;
  constraint c { regwen & ~ctrl_n != '0; }
endclass

class comparison_first;
  rand bit [7:0] mask;
  rand bit [7:0] ctrl_n;
  constraint c { (~ctrl_n != '0) & mask; }
endclass

class bitwise_or_bool;
  rand bit [7:0] mask;
  rand bit [7:0] ctrl_n;
  constraint c { mask | (ctrl_n == '0); }
endclass

class bitwise_xor_bool;
  rand bit [7:0] mask;
  rand bit [7:0] ctrl_n;
  constraint c { mask ^ (ctrl_n == '0); }
endclass

module top;
  reset_mask item;
  comparison_first left_bool;
  bitwise_or_bool or_bool;
  bitwise_xor_bool xor_bool;
  initial begin
    item = new;
    if (!item.randomize() with { regwen == 8'h03; ctrl_n == 8'h00; })
      $fatal(1, "comparison result should meet regwen bit 0");
    if (item.regwen != 8'h03 || item.ctrl_n != 8'h00)
      $fatal(1, "wrong first result");
    if (item.randomize() with { regwen == 8'h02; ctrl_n == 8'h00; })
      $fatal(1, "comparison result incorrectly matched regwen bit 1");
    left_bool = new;
    if (!left_bool.randomize() with { mask == 8'h03; ctrl_n == 8'h00; })
      $fatal(1, "comparison on left should be a one-bit operand");
    if (left_bool.randomize() with { mask == 8'h02; ctrl_n == 8'h00; })
      $fatal(1, "left comparison incorrectly matched mask bit 1");
    or_bool = new;
    if (!or_bool.randomize() with { mask == 8'h00; ctrl_n == 8'h00; })
      $fatal(1, "Boolean right operand should satisfy bitwise OR");
    if (or_bool.randomize() with { mask == 8'h00; ctrl_n == 8'h01; })
      $fatal(1, "false right operand incorrectly satisfied bitwise OR");
    xor_bool = new;
    if (!xor_bool.randomize() with { mask == 8'h00; ctrl_n == 8'h00; })
      $fatal(1, "Boolean right operand should satisfy bitwise XOR");
    if (xor_bool.randomize() with { mask == 8'h01; ctrl_n == 8'h00; })
      $fatal(1, "equal one-bit operands incorrectly satisfied bitwise XOR");
    $display("PASSED");
  end
endmodule
