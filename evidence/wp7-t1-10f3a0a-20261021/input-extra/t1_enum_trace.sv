typedef enum bit [3:0] { ITEM_A = 2, ITEM_B = 5, ITEM_C = 9 } item_e;

class t1_enum_item;
  rand item_e value;
  constraint selected { value inside {ITEM_B, ITEM_C}; }
endclass

module main;
  initial begin
    t1_enum_item item = new;
    item.srandom(32'h2468ace1);
    for (int draw = 0; draw < 64; draw++) begin
      if (!item.randomize()) $fatal(1, "randomize failed at %0d", draw);
      $display("%0d:%0d", draw, item.value);
    end
  end
endmodule
