class draw;
  rand bit value;
  constraint zero_c { value == 1'b0; }
endclass
module top;
  draw item;
  initial begin
    item = new();
    if (!(item.randomize() with { value == 1'b1; })) $fatal(1, "randomize failed");
    $display("SHOULD NOT PRINT");
  end
endmodule
