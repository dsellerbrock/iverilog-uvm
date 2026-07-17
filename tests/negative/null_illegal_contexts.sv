// IEEE 1800-2017 8.4 / 11.4.5: the literal `null` is only valid where a
// class handle is expected (assignment to a handle, ==/!=/===/!== against
// a handle). Using null as a scalar r-value or as an operand of a
// relational/bitwise/shift/logical operator must be a hard error in every
// language mode. The compile-progress class-type leniencies previously
// swallowed these, silently compiling `val = null` to `val = 0` and
// letting `null <= 1` abort the elaborator on a width-0 operand
// (br_gh440).
module top;
  logic [7:0] val;
  initial begin
    val = null;        // error: null r-value to a scalar target
    val = 1 | null;    // error: bitwise op on null
    val = null <= 1;   // error: relational op on null
    val = !null;       // error: logical negation of null
  end
endmodule
