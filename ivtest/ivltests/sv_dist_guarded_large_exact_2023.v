class guarded_large_item;
  rand bit enable;
  rand bit [10:0] value;
  constraint order_c { solve enable before value; }
  constraint distribution_c {
    if (enable) value dist {[1:300] :/ 1, [301:1000] :/ 3};
    else value == 0;
  }
endclass

class guarded_256_item;
  rand bit enable;
  rand bit [8:0] value;
  constraint order_c { solve enable before value; }
  constraint distribution_c {
    if (enable) value dist {[0:255] :/ 1};
    else value == 0;
  }
endclass

class guarded_257_item;
  rand bit enable;
  rand bit [8:0] value;
  constraint order_c { solve enable before value; }
  constraint distribution_c {
    if (enable) value dist {[0:256] :/ 1};
    else value == 0;
  }
endclass

module test;
  guarded_large_item large_item;
  guarded_256_item boundary_256;
  guarded_257_item boundary_257;
  int low_item_count;
  initial begin
    large_item = new;
    boundary_256 = new;
    boundary_257 = new;
    large_item.srandom(32'had_c0_2023);
    repeat (128) begin
      if (!large_item.randomize() with {enable == 1;})
        $fatal(1, "active guarded large dist randomize failed");
      if (large_item.value < 1 || large_item.value > 1000)
        $fatal(1, "active guarded large dist escaped hard range: %0d",
               large_item.value);
      if (large_item.value <= 300) low_item_count++;
    end
    if (low_item_count < 20 || low_item_count > 46)
      $fatal(1, "guarded :/ item weight ratio failed: %0d", low_item_count);
    if (!large_item.randomize() with {enable == 1; value == 17;})
      $fatal(1, "active guarded singleton constraint failed");
    if (!large_item.randomize() with {enable == 0;})
      $fatal(1, "inactive guarded distribution randomize failed");
    if (large_item.value != 0)
      $fatal(1, "inactive guarded distribution was applied: %0d",
             large_item.value);

    if (!boundary_256.randomize() with {enable == 1; value == 100;})
      $fatal(1, "guarded 256-value boundary failed");
    if (!boundary_257.randomize() with {enable == 1; value == 100;})
      $fatal(1, "guarded 257-value boundary failed");
    $display("PASSED");
  end
endmodule
