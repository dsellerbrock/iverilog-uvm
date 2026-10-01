typedef struct packed {
  logic [3:0] en;
  logic [3:0] sibling;
} region_t;
class region_holder;
  rand region_t regions[1];
  bit check;
  constraint c { if (check) regions[0].en == 4'h0; }
endclass
module test;
  region_holder item;
  initial begin
    item = new;
    item.regions[0].en = 4'h6;
    item.regions[0].sibling = 4'hx;
    item.regions.rand_mode(0);
    item.check = 0;
    if (!item.randomize()) $fatal(1, "inactive guarded read failed");
    item.check = 1;
    if (item.randomize() || item.regions[0].en !== 4'h6
        || item.regions[0].sibling !== 4'hx)
      $fatal(1, "X sibling fabricated a selected zero");
    $display("PASSED");
  end
endmodule
