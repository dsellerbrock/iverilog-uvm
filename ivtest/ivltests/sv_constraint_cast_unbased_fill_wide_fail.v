// The current constraint IR constant is limited to 64 bits. A wider fill
// cast must fail explicitly instead of solving to a truncated value.
typedef bit unsigned [64:0] wide65_t;
class item;
  rand int value;
endclass
module main;
  item obj;
  initial begin
    obj = new;
    if (obj.randomize() with { value == wide65_t'('1); })
      $fatal(1, "65-bit fill unexpectedly solved");
  end
endmodule
