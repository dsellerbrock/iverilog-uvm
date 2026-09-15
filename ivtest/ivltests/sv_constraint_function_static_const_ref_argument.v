class static_argument_item;
  static rand int y;
  rand int x;

  function automatic int identity(const ref int value);
    return value;
  endfunction

  constraint values_c {
    y == 9;
    x == identity(y);
  }
endclass

module test;
  static_argument_item item;
  initial begin
    item = new;
    static_argument_item::y = 2;
    if (!item.randomize())
      $fatal(1, "randomize failed");
    if (static_argument_item::y != 9 || item.x != 9)
      $fatal(1, "static argument dependency was not staged: y=%0d x=%0d",
             static_argument_item::y, item.x);
    $display("PASSED");
  end
endmodule
