class item;
  rand bit a[2];
  int i = 0;
  constraint c {
    foreach (a[i]) a[i] == i;
    i == 0;
    a.sum() with (int'(item)) == 1;
    a.sum(element) with (int'(element)) == 1;
  }
endclass

module top;
  item o;
  initial begin
    o = new;
    if (!o.randomize() || o.a[0] !== 0 || o.a[1] !== 1)
      $fatal(1, "foreach must use the loop index");
    o.i = 1;
    if (o.randomize())
      $fatal(1, "the reference after foreach must use the property");
    $display("PASSED");
  end
endmodule
