class mixed_leaf; rand bit [64:0] value[1]; endclass
class mixed_item;
  rand bit first, second;
  rand mixed_leaf child;
  constraint c {
    child.value[0] == 65'h1_02468ace_13579bdf;
    solve first before second;
    second <= first;
  }
  function new; child = new; endfunction
endclass
module test;
  initial begin
    mixed_item item;
    item = new;
    repeat (16) begin
      if (!item.randomize()) $fatal(1, "mixed randomize failed");
      if (item.child.value[0] !== 65'h1_02468ace_13579bdf ||
          item.second > item.first)
        $fatal(1, "mixed component semantics failed");
    end
    $display("PASSED");
  end
endmodule
