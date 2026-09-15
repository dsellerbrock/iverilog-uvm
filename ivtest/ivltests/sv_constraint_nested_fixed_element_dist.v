class dist_leaf;
  rand bit value[-1:0][2:3];
endclass
class dist_item;
  rand dist_leaf leaf;
  constraint weighted { leaf.value[-1][2] dist {0 := 0, 1 := 1}; }
  function new; leaf = new; endfunction
endclass
module test;
  initial begin
    dist_item item;
    item = new;
    repeat (16) begin
      if (!item.randomize()) $fatal(1, "randomize failed");
      if (item.leaf.value[-1][2] != 1)
        $fatal(1, "zero-weight nested element selected");
    end
    $display("PASSED");
  end
endmodule
