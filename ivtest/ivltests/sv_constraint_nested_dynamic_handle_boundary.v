// Growing a class-handle array creates null handles and does not randomize them.
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
    if (!cfg.randomize()) $fatal(1, "class-handle array resize failed");
    if (cfg.items.size() != 2 || cfg.items[0] != null || cfg.items[1] != null)
      $fatal(1, "class-handle array resize did not append null handles");
    $display("PASSED");
  end
endmodule
