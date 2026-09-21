class unordered_leaf;
  rand bit [7:0] value;
endclass
class unordered_large;
  randc bit cycle;
  rand bit first, second;
  rand bit [9:0] data;
  rand unordered_leaf child;
  function new; child = new; endfunction
  constraint c {
    cycle <= data[2];
    first == data[0];
    second == data[1];
    child.value == data[9:2];
    first dist {0 := 1, 1 := 3};
    second dist {0 := 3, 1 := 1};
  }
endclass
module test;
  unordered_large item = new;
  initial begin
    item.srandom(32'h554e4f52); item.child.srandom(32'h554e4f43);
    repeat (4)
      if (!item.randomize()) $fatal(1,"unordered large multi-dist randc failed");
    $display("PASSED");
  end
endmodule
