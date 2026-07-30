typedef struct { int x; int y; } pt_t;
class holder;
  static pt_t pool[3];
  function void seed(); pool[0].x = 3; pool[0].y = 7; endfunction
endclass
module top;
  holder h;
  initial begin
    h = new;
    h.seed();
    // Static property read through instance handle in a comparison:
    if (h.pool[0].x != 3) $display("MISCOMPARE: x=%0d", h.pool[0].x);
    else $display("x compared equal");
    $display("direct read: %0d (expected 3)", h.pool[0].x);
    $display("DONE");
  end
endmodule
