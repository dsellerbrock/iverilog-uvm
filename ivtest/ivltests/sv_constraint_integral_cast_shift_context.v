class shift_context_item;
  rand bit [7:0] raw;
  constraint c {
    raw == 8'h80;
    int'((signed'(raw) >>> 1) + 8'h00) == 64;
  }
endclass

module main;
  shift_context_item item = new;
  initial begin
    if (!item.randomize())
      $fatal(1, "mixed unsigned context did not reach arithmetic shift");
    $display("PASSED");
  end
endmodule
