// Focused signed-result metadata at a nested size-cast boundary.
typedef bit signed [7:0] s8_t;

class cast_signed_ops;
  rand bit [7:0] neg, pos, one;
  rand bit [15:0] wide;
  constraint c {
    neg == 8'h80;
    pos == 8'h7f;
    one == 1;
    wide == 16'hffff;

    // Shift and bitwise-negation results retain the left/operand sign.  The
    // intervening size cast must inherit it before int' widens the value.
    int'(8'(signed'(neg) >>> 1)) == -64;
    int'(8'(~signed'(neg))) == 127;
    int'(8'(~signed'(pos))) == -128;

    // Bitwise binary results are signed only when both operands are signed.
    int'(8'(signed'(neg) & signed'(8'hff))) == -128;
    int'(8'(signed'(neg) | signed'(pos))) == -1;
    int'(8'(signed'(neg) ^ signed'(pos))) == -1;

    // A mixed unsigned sibling selects one unsigned common context.  The
    // signed byte is zero-extended before the operation, not sign-extended
    // according to its leaf type.
    int'(signed'(neg) & wide) == 128;

    // Division already carries its common signed result through the same
    // nested boundary.
    int'(8'(signed'(neg) / s8_t'(2))) == -64;

    // One unsigned sibling makes the common arithmetic result unsigned;
    // widening after the size boundary must therefore produce +129.
    int'(8'(signed'(neg) + one)) == 129;

    // Arithmetic-right syntax fills with zero when its left operand is
    // unsigned; the parser still emits `ashr', so runtime type controls it.
    int'(8'(neg >>> 1)) == 64;
  }
endclass

module main;
  cast_signed_ops item = new;
  initial begin
    if (!item.randomize()) $fatal(1, "nested signed cast operators failed");
    if (item.neg != 8'h80 || item.pos != 8'h7f || item.one != 1
        || item.wide != 16'hffff)
      $fatal(1, "nested signed cast values changed");
    $display("PASSED");
  end
endmodule
