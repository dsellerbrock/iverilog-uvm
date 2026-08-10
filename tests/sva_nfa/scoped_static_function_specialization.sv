// Regression for a lifetime bug in SVA expression cloning: the cloned
// B#(2)::static_function() call borrowed its class-specialization actuals and
// could outlive them, causing a use-after-free / compiler segfault. Exercise
// both value- and type-parameter actuals in the legacy and NFA engines.
class B #(int VALUE = 0);
  static function automatic bit static_function();
    return VALUE == 2;
  endfunction
endclass

class BT #(type T = bit);
  static function automatic bit static_function();
    T value = T'(1);
    return value == T'(1);
  endfunction
endclass

module scoped_static_function_specialization;
  logic clk = 0;
  int passes = 0;
  always #5 clk = ~clk;

  scoped_call: assert property (@(posedge clk) B#(2)::static_function())
    passes++;
    else $fatal(1, "specialized static function returned false");

  scoped_type_call: assert property (
      @(posedge clk) BT#(int)::static_function())
    passes++;
    else $fatal(1, "type-specialized static function returned false");

  initial begin
    #6;
    if (passes != 2)
      $fatal(1, "assertions did not each pass exactly once: %0d", passes);
    $display("PASSED");
    $finish(0);
  end
endmodule
