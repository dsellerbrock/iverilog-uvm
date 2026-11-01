class complemented_range_item;
  rand bit [9:0] value;
  constraint distribution_c { (~value) dist {[10'd0:10'd300] :/ 1}; }
endclass

module test;
  complemented_range_item item;
  int succeeded, in_range;
  initial begin
    item = new;
    repeat (50) begin
      if (item.randomize()) begin
        succeeded++;
        if ((~item.value) <= 10'd300)
          in_range++;
        else
          $fatal(1, "complemented value outside dist range: %0d", ~item.value);
      end
    end
    if (succeeded != 50 || in_range != 50)
      $fatal(1, "succeeded %0d/50, ~value in [0:300] %0d/50", succeeded,
             in_range);
    $display("succeeded %0d/50, ~value in [0:300] %0d/50 (expected 50 and 50)",
             succeeded, in_range);
  end
endmodule
