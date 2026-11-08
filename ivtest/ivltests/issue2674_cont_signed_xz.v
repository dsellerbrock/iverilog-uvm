// Issue #2674: IEEE 1800-2017/2023 11.8.4 -- "If any bit of a signed value
// is X or Z, then any nonlogical operation involving the value shall result
// in the entire resultant value being an X." Continuous assignments must
// follow the rule as procedural assignments do (#1790). Unsigned and
// mixed-signedness operations (11.8.2) are not affected.
module test;
  logic signed [3:0] a = 4'b1x01, z = 4'b0z10, k = 4'b0101;
  logic signed [3:0] b = 4'b1111;
  logic [3:0] ua = 4'b1x01;
  logic [1:0] s = 2'd1;
  wire signed [3:0] w_and = a & b;
  wire signed [3:0] w_not = ~a;
  wire signed [3:0] w_shl = a << 1;
  wire signed [3:0] w_neg = -a;
  wire signed [3:0] w_or  = a | 4'sb0000;
  wire signed [3:0] w_xor = b ^ z;
  wire signed [3:0] w_xnr = a ~^ b;
  wire signed [3:0] w_ok  = k & b;
  wire        [3:0] w_u   = ua & 4'b1111;
  wire        [3:0] w_mix = a & 4'b1111;
  wire signed [3:0] w_dsh = a << s;
  wire signed [3:0] w_ash = a >>> 1;
  wire signed [3:0] w_pos = +a;
  wire signed [7:0] w_wide = a & 8'sb0000_1111;
  bit failed = 0;

  task check(input logic [3:0] got, input logic [3:0] exp, input string what);
    if (got !== exp) begin
      $display("FAILED: %s = %b, expected %b", what, got, exp);
      failed = 1;
    end
  endtask

  task check8(input logic [7:0] got, input logic [7:0] exp, input string what);
    if (got !== exp) begin
      $display("FAILED: %s = %b, expected %b", what, got, exp);
      failed = 1;
    end
  endtask

  initial begin
    #1;
    check(w_and, 4'bxxxx, "a & b");
    check(w_not, 4'bxxxx, "~a");
    check(w_shl, 4'bxxxx, "a << 1");
    check(w_neg, 4'bxxxx, "-a");
    check(w_or,  4'bxxxx, "a | 0");
    check(w_xor, 4'bxxxx, "b ^ z");
    check(w_xnr, 4'bxxxx, "a ~^ b");
    check(w_ok,  4'b0101, "k & b");
    check(w_u,   4'b1x01, "unsigned ua & f");
    check(w_mix, 4'b1x01, "mixed a & f");
    check(w_dsh, 4'bxxxx, "a << s");
    check(w_ash, 4'bxxxx, "a >>> 1");
    check(w_pos, 4'bxxxx, "+a");
    check8(w_wide, 8'bxxxxxxxx, "8-bit a & 8'sh0f");
    a = 4'b1001; z = 4'b0010;
    #1;
    check(w_and, 4'b1001, "a & b known");
    check(w_not, 4'b0110, "~a known");
    check(w_or,  4'b1001, "a | 0 known");
    check(w_xor, 4'b1101, "b ^ z known");
    check(w_xnr, 4'b1001, "a ~^ b known");
    check(w_dsh, 4'b0010, "a << s known");
    check(w_ash, 4'b1100, "a >>> 1 known");
    check(w_pos, 4'b1001, "+a known");
    check8(w_wide, 8'b00001001, "wide known");
    if (!failed) $display("PASSED");
  end
endmodule
