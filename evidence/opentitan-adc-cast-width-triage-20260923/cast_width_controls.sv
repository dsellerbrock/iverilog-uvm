typedef bit unsigned [0:0] bit1_t;
typedef bit unsigned [15:0] adc_value_t;
typedef bit unsigned [16:0] wide17_t;
typedef logic unsigned [15:0] logic16_t;

class item;
  rand int value;
endclass

module cast_width_controls;
  bit1_t one_bit;
  adc_value_t sixteen_bits;
  wide17_t seventeen_bits;
  logic16_t x_bits;
  logic16_t z_bits;
  item obj;
  initial begin
    one_bit = bit1_t'('1);
    sixteen_bits = adc_value_t'('1);
    seventeen_bits = wide17_t'('1);
    x_bits = logic16_t'('x);
    z_bits = logic16_t'('z);
    $display("direct widths: %0d:%0h %0d:%0h %0d:%0h", $bits(one_bit), one_bit,
             $bits(sixteen_bits), sixteen_bits, $bits(seventeen_bits), seventeen_bits);
    $display("direct X/Z: X=%h isunknown=%0d Z=%h isunknown=%0d", x_bits,
             $isunknown(x_bits), z_bits, $isunknown(z_bits));

    obj = new;
    if (!obj.randomize()) $fatal(1, "unconstrained control randomize failed");
    $display("unconstrained control: width=%0d value=%0h", $bits(obj.value), obj.value);
    if (!obj.randomize() with { value == 16'hffff; })
      $fatal(1, "sized-literal inline constraint failed");
    $display("sized-literal constraint: width=%0d value=%0h", $bits(obj.value), obj.value);
    if (!obj.randomize() with { value == adc_value_t'('1); })
      $fatal(1, "16-bit casted fill inline constraint failed");
    $display("16-bit casted fill constraint: width=%0d value=%0h", $bits(obj.value), obj.value);
    if (!obj.randomize() with { value == wide17_t'('1); })
      $fatal(1, "17-bit casted fill inline constraint failed");
    $display("17-bit casted fill constraint: width=%0d value=%0h", $bits(obj.value), obj.value);
    if (!obj.randomize() with { value == adc_value_t'(1'b1); })
      $fatal(1, "sized one-bit operand cast inline constraint failed");
    $display("casted sized one-bit constraint: width=%0d value=%0h", $bits(obj.value), obj.value);
    $finish;
  end
endmodule
