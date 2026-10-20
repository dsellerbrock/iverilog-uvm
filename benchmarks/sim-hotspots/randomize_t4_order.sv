class ordered_item;
  rand bit first, second;
  constraint c { solve first before second; first == 1'b1; }
endclass

module main;
  initial begin
    ordered_item item = new;
    if (!item.randomize()) $fatal(1, "solve-before randomize failed");
    $display("%0d,%0d", item.first, item.second);
  end
endmodule
