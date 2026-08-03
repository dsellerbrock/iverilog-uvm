// IEEE 1800-2017 18.5.4: dist weights are integral expressions evaluated
// when randomize() is called. A zero-weight item is excluded.

class dist_runtime_weight_item;
  rand bit choice;
  int unsigned zero_weight;

  constraint choice_c {
    choice dist {
      0 :/ zero_weight,
      1 :/ (100 - zero_weight)
    };
  }
endclass

module dist_runtime_weight_test;
  initial begin
    dist_runtime_weight_item item;
    item = new;

    item.zero_weight = 0;
    repeat (10) begin
      if (!item.randomize() || item.choice != 1) begin
        $display("FAIL: zero runtime weight selected choice 0");
        $finish(1);
      end
    end

    item.zero_weight = 100;
    repeat (10) begin
      if (!item.randomize() || item.choice != 0) begin
        $display("FAIL: updated runtime weight selected choice 1");
        $finish(1);
      end
    end

    $display("PASS");
  end
endmodule
