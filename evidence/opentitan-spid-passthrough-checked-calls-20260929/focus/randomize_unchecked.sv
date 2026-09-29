class draw;
  rand bit value;
  constraint zero_c { value == 1'b0; }
endclass
module top;
  draw item;
  initial begin
    item = new();
    item.randomize() with { value == 1'b1; };
    $display("unchecked value=%b", item.value);
  end
endmodule
