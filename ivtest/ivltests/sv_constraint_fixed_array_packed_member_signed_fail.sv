typedef struct packed { bit signed [3:0] en; } region_t;
class signed_member;
  rand region_t regions[2];
  constraint c { regions[1'bx].en == -4'sd2; }
endclass
module test;
  signed_member item;
  initial begin
    item = new;
    if (item.randomize()) $fatal(1, "signed member was accepted");
    $display("PASSED");
  end
endmodule
