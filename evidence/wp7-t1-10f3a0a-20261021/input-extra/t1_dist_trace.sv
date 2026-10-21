class t1_dist_item;
  rand bit [3:0] value;
  constraint weighted {
    value dist { [4'd2:4'd4] := 3, 4'd4 :/ 2, [4'd7:4'd8] :/ 4 };
  }
endclass

module main;
  initial begin
    t1_dist_item item = new;
    item.srandom(32'h10293847);
    for (int draw = 0; draw < 64; draw++) begin
      if (!item.randomize()) $fatal(1, "randomize failed at %0d", draw);
      $display("%0d:%0d", draw, item.value);
    end
  end
endmodule
