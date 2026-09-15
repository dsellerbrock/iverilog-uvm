class deep_base; rand bit signed [1:0] value[-1:0][2:3]; endclass
class deep_leaf extends deep_base; endclass
class deep_middle; rand deep_leaf leaf; endclass
class deep_item;
  rand bit expected;
  rand deep_middle middle;
  constraint exact { expected == 1; middle.leaf.value[-1][2] == 2'sd1; }
  function new; middle = new; middle.leaf = new; endfunction
endclass
module test;
  initial begin
    deep_item item;
    item = new;
    repeat (8) begin
      if (!item.randomize() || item.middle.leaf.value[-1][2] !== 2'sd1)
        $fatal(1, "deep multidimensional inherited element failed");
    end
    $display("PASSED");
  end
endmodule
