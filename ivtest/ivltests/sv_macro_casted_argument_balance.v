// Macro actual arguments must keep a cast operand's parentheses balanced.
// IEEE 1800-2017/2023 22.5.1; casts use 6.24.1 and the unbased unsized
// literal from 5.7.1.
typedef logic [3:0] nibble_t;
typedef nibble_t lane_array_t [2];

`define FIRST2(a, b) a
`define SECOND2(a, b) b

module sv_macro_casted_argument_balance;
  localparam nibble_t casted = `FIRST2(nibble_t'('1), (2 + 3));
  localparam bit ordinary_unbased = `FIRST2('1, 1'b0);
  localparam [1:0] concatenated = `FIRST2({1'b0, 1'b1}, 2'b00);
  localparam int comma_after_cast = `SECOND2(nibble_t'('1), 7);
  localparam int comment_boundary = `SECOND2(0 /* comma , and close ) */, 9);
  lane_array_t pattern;

  initial begin
    pattern = `FIRST2(lane_array_t'{'1, '0}, '{'0, '1});
    if (casted !== 4'hf || ordinary_unbased !== 1'b1 ||
        concatenated !== 2'b01 ||
        comma_after_cast != 7 || comment_boundary != 9 ||
        pattern[0] !== 4'hf || pattern[1] !== 4'h0)
      $fatal(1, "macro actual argument boundaries changed");
    if (`FIRST2("comma, ) in string", "ignored") != "comma, ) in string")
      $fatal(1, "string macro argument boundary changed");
    $display("PASS macro casted argument balance");
  end
endmodule
