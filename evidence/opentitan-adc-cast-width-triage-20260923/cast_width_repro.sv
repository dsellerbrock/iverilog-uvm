typedef bit unsigned [15:0] adc_value_t;

class adc_item;
  rand int ramp_max;
endclass

module cast_width_repro;
  adc_item item;
  adc_value_t literal_cast;
  int no_constraint_value;
  initial begin
    literal_cast = adc_value_t'('1);
    $display("literal_cast width=%0d value=0x%0h", $bits(literal_cast), literal_cast);
    item = new;
    if (!item.randomize() with { ramp_max == adc_value_t'('1); })
      $fatal(1, "inline cast constraint failed");
    $display("inline_constraint width=%0d value=0x%0h", $bits(item.ramp_max), item.ramp_max);
    if (!item.randomize())
      $fatal(1, "no-constraint randomize failed");
    no_constraint_value = item.ramp_max;
    $display("no_constraint width=%0d value=0x%0h", $bits(item.ramp_max), no_constraint_value);
    $finish;
  end
endmodule
