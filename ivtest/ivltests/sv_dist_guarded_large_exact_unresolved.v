class unresolved_guard_item;
  rand bit enable;
  rand bit [10:0] value;
  constraint distribution_c {
    if (enable) value dist {[1:1000] :/ 1};
    else value == 0;
  }
endclass

module test;
  unresolved_guard_item item;
  initial begin
    item = new;
    if (item.randomize())
      $fatal(1, "unresolved large-dist guard was silently accepted");
    $display("PASSED unresolved guard was rejected");
  end
endmodule
