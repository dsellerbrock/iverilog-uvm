class feasible_item;
  rand bit [7:0] data[];
  constraint c {
    data.size() inside {[0:3]};
    foreach (data[i]) data[i] == 8'h00 && data[i] == 8'h01;
  }
endclass

class infeasible_item;
  rand bit [7:0] data[];
  constraint c {
    data.size() inside {[1:3]};
    foreach (data[i]) data[i] == 8'h00 && data[i] == 8'h01;
  }
endclass

module main;
  initial begin
    feasible_item good;
    infeasible_item bad;
    int passed;
    good = new;
    bad = new;
    passed = 0;
    repeat (20) begin
      if (good.randomize() && good.data.size() == 0) passed++;
      else $fatal(1, "feasible randomize failed or chose nonempty data");
    end
    repeat (20) begin
      if (bad.randomize()) $fatal(1, "infeasible randomize succeeded");
    end
    $display("issue1725 %0d/20, infeasible rejected", passed);
  end
endmodule
