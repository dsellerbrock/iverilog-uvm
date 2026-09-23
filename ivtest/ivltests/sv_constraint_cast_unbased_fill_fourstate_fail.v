// A four-state fill cannot be silently reduced to a two-state c:0 token.
typedef logic [15:0] logic16_t;
class item;
  rand int value;
endclass
module main;
  item obj;
  initial begin
    obj = new;
    if (obj.randomize() with { value == logic16_t'('x); })
      $fatal(1, "four-state fill unexpectedly solved");
  end
endmodule
