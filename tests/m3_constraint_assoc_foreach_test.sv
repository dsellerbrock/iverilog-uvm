// IEEE 1800-2017 18.5.8.1: foreach constraints on a random associative
// array apply to every element that exists when randomize() is called.

class m3_assoc_foreach_item;
  rand int unsigned freq_mhz[string];

  constraint freq_c {
    foreach (freq_mhz[name]) freq_mhz[name] inside {[5:100]};
  }
endclass

module m3_constraint_assoc_foreach_test;
  initial begin
    m3_assoc_foreach_item item;
    item = new;
    item.freq_mhz["core"] = 0;
    item.freq_mhz["peripheral"] = 0;

    if (!item.randomize()) begin
      $display("FAIL: associative-array randomize returned false");
      $finish(1);
    end
    if (!item.freq_mhz.exists("core") ||
        !item.freq_mhz.exists("peripheral")) begin
      $display("FAIL: associative-array keys changed during randomize");
      $finish(1);
    end
    if (!(item.freq_mhz["core"] inside {[5:100]}) ||
        !(item.freq_mhz["peripheral"] inside {[5:100]})) begin
      $display("FAIL: associative values were not constrained: %0d %0d",
               item.freq_mhz["core"], item.freq_mhz["peripheral"]);
      $finish(1);
    end

    $display("PASS");
  end
endmodule
