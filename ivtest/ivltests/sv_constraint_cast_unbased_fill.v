// IEEE 1800-2017/2023 5.7.1, 6.24.1, 18.5: an unbased fill operand
// takes its direct cast's width before a constraint compares the value.
typedef bit unsigned [0:0] bit1_t;
typedef bit unsigned [15:0] adc_value_t;
typedef bit unsigned [16:0] wide17_t;
typedef bit unsigned [63:0] wide64_t;
typedef logic unsigned [15:0] logic16_t;

class adc_item;
  rand int value;
endclass

class wide_item;
  rand wide64_t value;
endclass

module main;
  adc_item item;
  wide_item wide;
  logic16_t x_bits, z_bits;
  int retained;
  initial begin
    // Procedural four-state casts are unaffected by the solver path.
    x_bits = logic16_t'('x);
    z_bits = logic16_t'('z);
    if (x_bits !== 16'hxxxx || z_bits !== 16'hzzzz)
      $fatal(1, "procedural X/Z casts changed");

    item = new;
    if (!item.randomize() with { value == bit1_t'('1); }
        || item.value != 1)
      $fatal(1, "one-bit fill cast");
    if (!item.randomize() with { value == adc_value_t'('1); }
        || item.value != 32'h0000ffff)
      $fatal(1, "16-bit fill cast");
    if (!item.randomize() with { value == wide17_t'('1); }
        || item.value != 32'h0001ffff)
      $fatal(1, "17-bit fill cast");
    if (!item.randomize() with { value == adc_value_t'('0); }
        || item.value != 0)
      $fatal(1, "zero fill cast");
    if (!item.randomize() with { value == adc_value_t'(1'b1); }
        || item.value != 1)
      $fatal(1, "sized one-bit cast");
    if (!item.randomize() with { value == adc_value_t'('x); }
        || item.value != 0)
      $fatal(1, "two-state X fill cast");
    if (!item.randomize() with { value == adc_value_t'('z); }
        || item.value != 0)
      $fatal(1, "two-state Z fill cast");

    if (!item.randomize() with {
      value == adc_value_t'('1);
      value == 32'h0000ffff;
    } || item.value != 32'h0000ffff)
      $fatal(1, "compatible conjunction");
    retained = item.value;
    if (item.randomize() with {
      value == adc_value_t'('1);
      value == 1;
    } || item.value != retained)
      $fatal(1, "contradictory conjunction did not roll back");

    wide = new;
    if (!wide.randomize() with { value == wide64_t'('1); }
        || wide.value != 64'hffff_ffff_ffff_ffff)
      $fatal(1, "64-bit fill cast");
    $display("PASSED");
  end
endmodule
