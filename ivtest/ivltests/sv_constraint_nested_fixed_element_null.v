class null_leaf; rand bit value[1]; endclass
class null_item;
  rand bit held;
  rand null_leaf leaf;
  constraint link { leaf.value[0] == held; }
endclass
module test;
  initial begin
    null_item item;
    item = new; item.held = 1;
    if (item.randomize()) $fatal(1, "null nested owner was accepted");
    if (item.held != 1 || item.leaf != null) $fatal(1, "null failure changed state");
    $display("PASSED");
  end
endmodule
