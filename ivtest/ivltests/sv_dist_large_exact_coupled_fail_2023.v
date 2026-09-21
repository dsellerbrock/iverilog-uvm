class coupled_item;
  rand bit [9:0] value;
  rand bit [9:0] auxiliary;
  constraint distribution_c { value dist {[0:300] :/ 1}; }
  constraint coupled_c { auxiliary == value + 1; }
endclass

module test;
  coupled_item item;
  initial begin
    item = new;
    if (item.randomize()) $fatal(1, "unsupported coupled sampler succeeded");
    $display("PASSED");
  end
endmodule
