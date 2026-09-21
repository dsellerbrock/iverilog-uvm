class pinned_state_item;
  rand bit [9:0] value;
  rand bit [9:0] bound;
  rand bit unrelated;
  constraint distribution_c {
    value dist {[0:300] :/ 1, [301:700] :/ 3};
  }
  constraint state_c { value < bound; }
  constraint independent_c { unrelated inside {0, 1}; }
endclass

module test;
  pinned_state_item item;
  int low, high;
  initial begin
    item = new;
    item.bound = 400;
    item.bound.rand_mode(0);
    item.srandom(32'h51a7_e001);
    repeat (128) begin
      if (!item.randomize()) $fatal(1, "randomize failed");
      if (item.value > 399) $fatal(1, "pinned bound ignored: %0d", item.value);
      if (item.value <= 300) low++; else high++;
    end
    if (low < 7 || low > 65)
      $fatal(1, "pinned-state exact item ratio failed");
    $display("PASSED");
  end
endmodule
