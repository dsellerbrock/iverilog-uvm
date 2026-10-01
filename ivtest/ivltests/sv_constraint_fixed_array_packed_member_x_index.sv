typedef struct packed { bit [3:0] en; } region_t;
class unknown_index;
  rand region_t regions[2];
  constraint c { regions[1'bx].en == 4'h6; }
endclass
module test;
  unknown_index item;
  initial begin
    item = new;
    if (item.randomize()) $fatal(1, "X index was accepted");
    $display("PASSED");
  end
endmodule
