// A class-handle array still cannot use nested value-array resize writeback.
class nested_handle_item;
  rand bit value;
endclass

class nested_handle_cfg;
  rand nested_handle_item items[];
  constraint size_c { items.size == 2; }
endclass

module test;
  nested_handle_cfg cfg = new;
  initial begin
    if (cfg.randomize()) $fatal(1, "unsupported handle resize succeeded");
    if (cfg.items.size() != 0)
      $fatal(1, "failed handle resize changed the array");
    $display("PASSED");
  end
endmodule
