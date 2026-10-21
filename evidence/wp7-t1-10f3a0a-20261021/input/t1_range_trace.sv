class t1_range_item;
  rand bit [3:0] value;
  constraint bounded { value inside {[4'd2:4'd9]}; }
endclass

module main;
  initial begin
    t1_range_item item = new;
    item.srandom(32'h13579bdf);
    for (int draw = 0; draw < 64; draw++) begin
      if (!item.randomize()) $fatal(1, "randomize failed at %0d", draw);
      $display("%0d:%0d", draw, item.value);
    end
  end
endmodule
