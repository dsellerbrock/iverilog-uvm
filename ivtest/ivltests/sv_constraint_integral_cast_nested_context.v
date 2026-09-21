class nested_context_item;
  rand bit [7:0] raw;
  constraint c {
    raw == 8'h80;
    int'((~(signed'(raw) >>> 1) | 8'h00) + 16'h0000) == -65;
  }
endclass

module main;
  nested_context_item item = new;
  initial begin
    if (!item.randomize())
      $fatal(1, "nested unsigned context did not reach signed shift");
    $display("PASSED");
  end
endmodule
