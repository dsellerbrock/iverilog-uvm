class target_c;
  rand int value;
endclass

module test;
  target_c item;

  initial begin
    item = new;
    void'(item.randomize() with (missing) { missing == 1; });
    void'(item.randomize() with (missing) { });
  end
endmodule
