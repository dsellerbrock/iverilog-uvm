typedef bit unsigned [15:0] adc_value_t;
class item;
  rand int value;
endclass
module cast_width_unsat_control;
  item obj;
  bit solved;
  initial begin
    obj = new;
    solved = obj.randomize() with {
      value == adc_value_t'('1);
      value == 32'h0000ffff;
    };
    $display("compatible cast-fill plus explicit 16'hffff: solved=%0d value=0x%0h", solved, obj.value);
    solved = obj.randomize() with {
      value == adc_value_t'('1);
      value == 1;
    };
    $display("contradictory cast-fill plus value=1: solved=%0d value=0x%0h", solved, obj.value);
    $finish;
  end
endmodule
