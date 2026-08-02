module dist_open_range_test;
  class item_c;
    rand int value;
    constraint bounds_c { value inside {[0:15]}; }
    constraint open_dist_c { value dist {[1:$] :/ 2}; }
  endclass

  item_c item;

  initial begin
    item = new;
    repeat (20) begin
      if (!item.randomize()) begin
        $display("FAIL: open-ended dist constraint was unsatisfiable");
        $finish(1);
      end
      if (item.value < 1 || item.value > 15) begin
        $display("FAIL: open-ended dist produced %0d", item.value);
        $finish(1);
      end
    end
    $display("PASS: weighted dist accepts and enforces [lo:$]");
    $finish;
  end
endmodule
